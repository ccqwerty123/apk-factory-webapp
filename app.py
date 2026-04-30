import os
import subprocess
import shutil
import json
import requests
import tempfile
import xml.etree.ElementTree as ET
from flask import Flask, render_template, request, send_from_directory, url_for
from bs4 import BeautifulSoup
from urllib.parse import quote
from typing import Optional, List, Dict, Any

# ==============================================================================
# 0. Flask 应用初始化
# ==============================================================================
app = Flask(__name__)
os.makedirs("/workspace/apk_factory/output", exist_ok=True)

# ==============================================================================
# 1. 系统与工具路径 (全局配置)
# ==============================================================================
TEMPLATE_APK_PATH = "/workspace/apk_factory/input/1.apk"
WORKING_DIR = "/workspace/apk_factory/working"
OUTPUT_DIR = "/workspace/apk_factory/output"
ANDROID_BUILD_TOOLS_DIR = "/workspace/tools/android-sdk/build-tools/34.0.0"
APKTOOL_PATH = "/workspace/tools/apktool.jar"
KEYSTORE_PATH = "/workspace/secure/my-release-key.keystore"
KEYSTORE_PASS = "hao123"
KEY_ALIAS = "my-key-alias"
ZIPALIGN_PATH = os.path.join(ANDROID_BUILD_TOOLS_DIR, "zipalign")
APKSIGNER_PATH = os.path.join(ANDROID_BUILD_TOOLS_DIR, "apksigner")
DEFAULT_APP_INFO = {"app_name": "默认启动器", "package_name": "com.default.launcher", "version_name": "1.0.0", "version_code": "1"}

# ==============================================================================
# 2. 应用信息抓取与 APK 分析模块
# ==============================================================================

# --- [新增] APK权限预读功能 ---
def get_apk_permissions(apk_path: str) -> List[str]:
    """
    预先解包一个APK，只为了读取并返回其AndroidManifest.xml中声明的所有权限列表。
    使用临时目录确保操作是干净和安全的。
    """
    permissions = []
    # 使用临时目录，执行完毕后会自动清理，非常适合Web应用
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            print(f"🔍 Pre-scanning permissions from {apk_path}...")
            run_command(f"java -jar {APKTOOL_PATH} d -f -s {apk_path} -o {temp_dir}", suppress_output=True)
            
            manifest_path = os.path.join(temp_dir, "AndroidManifest.xml")
            if os.path.exists(manifest_path):
                tree = ET.parse(manifest_path)
                root = tree.getroot()
                android_ns = '{http://schemas.android.com/apk/res/android}'
                for perm_tag in root.findall('uses-permission'):
                    permission_name = perm_tag.get(f'{android_ns}name')
                    if permission_name:
                        permissions.append(permission_name)
            print(f"✅ Found {len(permissions)} permissions.")
            return sorted(permissions) # 排序让显示更美观
        except Exception as e:
            print(f"❌ Error while scanning permissions: {e}")
            return [] # 如果出错，返回空列表

# --- 全局坐标缓存 ---
# 格式示例: ["props", "pageProps", "dynamicCardResponse", "data", "components", 0, "data", "itemData"]
YYB_COORDINATES = []

def get_yyb_json(query: str):
    """底层函数：仅负责获取网页中的 JSON 对象"""
    url = "https://sj.qq.com/search?q=" + quote(query)
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'}
    try:
        response = requests.get(url, headers=headers, timeout=10)
        soup = BeautifulSoup(response.text, 'lxml')
        script_tag = soup.find('script', id='__NEXT_DATA__')
        return json.loads(script_tag.string) if script_tag else None
    except:
        return None

def find_path_by_value(node: Any, target_val: str, current_path: list) -> Optional[list]:
    """递归搜索：在JSON树中定位包含目标值的“列表”路径"""
    # 如果当前是列表，检查里面的字典是否有我们要的包名
    if isinstance(node, list):
        for i, item in enumerate(node):
            if isinstance(item, dict) and any(v == target_val for v in item.values()):
                return current_path # 找到了，返回父级（列表）的路径
            # 继续往深层找
            if (found := find_path_by_value(item, target_val, current_path + [i])):
                return found
    # 如果当前是字典，遍历键值对
    elif isinstance(node, dict):
        for k, v in node.items():
            if (found := find_path_by_value(v, target_val, current_path + [k])):
                return found
    return None

def get_value_by_path(data: Any, path: list) -> Any:
    """根据路径安全地从JSON中取值"""
    try:
        for step in path:
            data = data[step]
        return data
    except:
        return None

def search_and_parse(query: str) -> List[Dict[str, str]]:
    """[自愈版] 搜索并解析腾讯应用宝的应用信息"""
    global YYB_COORDINATES
    print(f"🔍 正在搜索: '{query}'")
    
    # 1. 获取目标查询的 JSON 数据
    page_data = get_yyb_json(query)
    if not page_data: return []

    target_list = None

    # 2. 如果有缓存坐标，先尝试直接取
    if YYB_COORDINATES:
        target_list = get_value_by_path(page_data, YYB_COORDINATES)
    
    # 3. 坐标失效或初次运行：利用“微信”反推坐标
    # 逻辑：即使搜支付宝，结果里也常带有微信推荐；如果没有，就专门校准一次。
    if not isinstance(target_list, list):
        print("📍 坐标丢失或页面改版，正在定位‘com.tencent.mm’轴点...")
        # 尝试从当前数据里找微信
        path = find_path_by_value(page_data, "com.tencent.mm", [])
        
        if not path:
            # 如果当前结果没微信，强制搜一次微信来校准
            calib_data = get_yyb_json("微信")
            path = find_path_by_value(calib_data, "com.tencent.mm", [])
            
        if path:
            YYB_COORDINATES = path
            print(f"✅ 坐标对焦成功: {' -> '.join(map(str, path))}")
            target_list = get_value_by_path(page_data, YYB_COORDINATES)

    if not target_list or not isinstance(target_list, list):
        print("❌ 无法定位应用列表容器")
        return []

    # 4. 万能提取：自适应字段名
    results = []
    for app in target_list:
        if not isinstance(app, dict): continue
        # 只要字典里看起来像应用信息（有包名），就提取
        pkg = app.get('pkg_name') or app.get('pkgname') or app.get('package_name')
        if not pkg: continue
        
        results.append({
            "app_name": app.get('name') or app.get('appname') or app.get('title', 'N/A'),
            "developer": app.get('developer') or app.get('operator') or 'N/A',
            "package_name": pkg,
            "version_name": app.get('version_name') or app.get('version', 'N/A'),
            "icon_url": app.get('icon') or app.get('icon_url') or ''
        })
    
    return results



# ==============================================================================
# 3. APK 重打包核心模块 (已升级)
# ==============================================================================
def run_command(command: str, suppress_output: bool = False):
    """执行shell命令"""
    if not suppress_output: print(f"🚀 Executing: {command}")
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout, stderr = process.communicate()
    if not suppress_output:
        if stdout: print(f"   stdout: {stdout.strip()}")
        if stderr: print(f"   stderr: {stderr.strip()}")
    if process.returncode != 0:
        raise subprocess.CalledProcessError(process.returncode, command, output=stdout, stderr=stderr)

# ==============================================================================
# 请将您的旧函数替换为下面这个完整的新版本
# ==============================================================================
def modify_manifest(manifest_path: str, package_name: str, version_name: str, version_code: str, app_name: str, permissions_to_keep: List[str]):
    """
    [已升级] 修改 AndroidManifest.xml，包括移除未被选中的权限，并动态修复ContentProvider的authorities冲突。
    """
    import xml.etree.ElementTree as ET
    print(f"🔧 Modifying {manifest_path}...")
    
    # 注册 'android' 命名空间，这样ET库才能正确解析和写入 android:xxx 这样的属性
    ET.register_namespace('android', "http://schemas.android.com/apk/res/android")
    
    tree = ET.parse(manifest_path)
    root = tree.getroot()
    android_ns = '{http://schemas.android.com/apk/res/android}'
    
    # --- 步骤 1: 获取原始包名 ---
    # 在修改它之前，先把它存起来。这是我们用来查找和替换的“关键词”。
    original_package_name = root.get('package')
    
    # --- 步骤 2: 修改应用基本属性 (这部分是您已有的逻辑) ---
    root.set('package', package_name)
    root.set(f'{android_ns}versionCode', version_code)
    root.set(f'{android_ns}versionName', version_name)
    
    application_node = root.find('application')
    if application_node is not None:
        application_node.set(f'{android_ns}label', app_name)
    else:
        raise FileNotFoundError("<application> tag not found.")

    # --- 步骤 3: 动态修复 ContentProvider authorities (这是新增的核心逻辑) ---
    print(f"  🔍 Searching for ContentProviders to fix authorities...")
    # 这个if判断确保我们只在包名确实被修改时才执行替换，更安全。
    if original_package_name and original_package_name != package_name:
        # 遍历 <application> 标签下的所有 <provider> 标签
        for provider in application_node.findall('provider'):
            authorities_attr = f'{android_ns}authorities'
            old_authorities = provider.get(authorities_attr)
            
            # 检查这个provider是否有authorities，并且它的值包含了原始包名
            if old_authorities and original_package_name in old_authorities:
                # 使用Python的字符串替换功能，生成新的authorities值
                new_authorities = old_authorities.replace(original_package_name, package_name)
                
                # 将计算出的新值设置回provider标签的authorities属性
                provider.set(authorities_attr, new_authorities)
                
                # 打印日志，方便调试和确认
                print(f"     ✅ Fixed authority: {old_authorities} -> {new_authorities}")

    # --- 步骤 4: 根据勾选的列表移除权限 (这也是您已有的逻辑) ---
    print("  🔥 Pruning permissions...")
    permissions_in_manifest = root.findall('uses-permission')
    for perm_tag in permissions_in_manifest:
        permission_name = perm_tag.get(f'{android_ns}name')
        if permission_name not in permissions_to_keep:
            print(f"     - Removing permission: {permission_name}")
            root.remove(perm_tag)
    
    # --- 步骤 5: 将所有修改写回文件 ---
    tree.write(manifest_path, encoding='utf-8', xml_declaration=True)

def repackage_apk(config: dict) -> str:
    """执行完整的APK重打包流程，并返回最终文件名"""
    final_apk_name = f"{config['app_name'].replace(' ', '_')}-v{config['version_name']}.apk"
    signed_apk_path = os.path.join(OUTPUT_DIR, final_apk_name)
    task_dir = os.path.join(WORKING_DIR, config['package_name'])
    
    if os.path.exists(task_dir): shutil.rmtree(task_dir)
    os.makedirs(task_dir)
    
    try:
        decoded_dir = os.path.join(task_dir, "decoded")
        run_command(f"java -jar {APKTOOL_PATH} d -f {TEMPLATE_APK_PATH} -o {decoded_dir}")

        manifest_path = os.path.join(decoded_dir, "AndroidManifest.xml")
        modify_manifest(manifest_path, config['package_name'], config['version_name'], config['version_code'], config['app_name'], config['permissions_to_keep'])
        
        unsigned_apk_path = os.path.join(task_dir, "unsigned_unaligned.apk")
        run_command(f"java -jar {APKTOOL_PATH} b --use-aapt2 {decoded_dir} -o {unsigned_apk_path}")
        
        aligned_apk_path = os.path.join(task_dir, "aligned.apk")
        run_command(f"{ZIPALIGN_PATH} -v 4 {unsigned_apk_path} {aligned_apk_path}")
        
        sign_command = (f"{APKSIGNER_PATH} sign --ks {KEYSTORE_PATH} --ks-key-alias \"{KEY_ALIAS}\" --ks-pass pass:{KEYSTORE_PASS} --out {signed_apk_path} {aligned_apk_path}")
        run_command(sign_command)
        
        run_command(f"{APKSIGNER_PATH} verify -v {signed_apk_path}")
        return final_apk_name
    finally:
        if os.path.exists(task_dir): shutil.rmtree(task_dir)


# ==============================================================================
# 4. Flask Web 路由 (已升级)
# ==============================================================================
@app.route('/', methods=['GET', 'POST'])
def index():
    """主页面，处理搜索和显示结果"""
    search_results, query = [], ""
    if request.method == 'POST':
        query = request.form.get('query', '')
        if query: 
            search_results_raw = search_and_parse(query)
            
            # --- [核心修改开始] ---
            # 为了绕过模板中可能存在问题的 `tojson` 过滤器，我们在此处手动为每个结果生成一个干净的JSON字符串。
            processed_results = []
            for app_dict in search_results_raw:
                # 使用Python内置的、绝对可靠的 `json` 库来创建JSON字符串。
                # `ensure_ascii=False` 确保中文字符不会被转义成 \uXXXX 的形式，更具可读性。
                app_dict['json_str'] = json.dumps(app_dict, ensure_ascii=False)
                processed_results.append(app_dict)
            
            # 使用我们处理过的新列表进行后续操作
            search_results = processed_results
            # --- [核心修改结束] ---

    initial_values = DEFAULT_APP_INFO
    if search_results:
        first = search_results[0]
        initial_values = {"app_name": first.get('app_name'), "package_name": first.get('package_name'), "version_name": first.get('version_name'), "version_code": "1"}

    # --- [新增] 每次加载页面时，都读取模板APK的权限 ---
    all_permissions = get_apk_permissions(TEMPLATE_APK_PATH)

    return render_template('index.html', search_results=search_results, query=query, initial_values=initial_values, all_permissions=all_permissions)


@app.route('/generate', methods=['POST'])
def generate():
    """处理APK生成请求"""
    try:
        # --- [新增] 从表单获取用户勾选的权限列表 ---
        permissions_to_keep = request.form.getlist('permissions_to_keep')

        app_config = {
            "app_name": request.form['app_name'], "package_name": request.form['package_name'],
            "version_name": request.form['version_name'], "version_code": request.form['version_code'],
            "permissions_to_keep": permissions_to_keep  # 将权限列表加入配置
        }
        
        print("收到的生成请求:", app_config)
        final_apk_filename = repackage_apk(app_config)
        download_url = url_for('download_file', filename=final_apk_filename)
        
        return render_template('index.html', download_link=download_url, apk_filename=final_apk_filename,
                               initial_values=app_config, all_permissions=get_apk_permissions(TEMPLATE_APK_PATH))
    except Exception as e:
        print(f"生成APK时发生严重错误: {e}")
        return render_template('index.html', error_message=str(e),
                               initial_values=request.form, all_permissions=get_apk_permissions(TEMPLATE_APK_PATH))

@app.route('/download/<filename>')
def download_file(filename):
    """提供文件下载"""
    return send_from_directory(OUTPUT_DIR, filename, as_attachment=True)

# ==============================================================================
# 5. 启动应用
# ==============================================================================
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
