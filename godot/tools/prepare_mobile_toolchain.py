"""Fetch verified official export templates, Temurin JDK 17 and minimal Android SDK locally."""
import hashlib, json, os, secrets, shutil, subprocess, urllib.request, zipfile
import xml.etree.ElementTree as ET
from pathlib import Path
from fetch_windows_template import RemoteZip, URL
project = Path(__file__).resolve().parents[1]
build = project/'.build'
cache = build/'downloads';cache.mkdir(parents=True,exist_ok=True)
receipts = []
def get(url):
    request=urllib.request.Request(url,headers={'User-Agent':'ZhongRiZi-build/0.26'})
    with urllib.request.urlopen(request,timeout=90) as response: return response.read()
def download(url, filename, expected=None, algorithm='sha256'):
    path=cache/filename
    if not path.exists():
        with urllib.request.urlopen(url,timeout=120) as response,path.open('wb') as output:
            shutil.copyfileobj(response,output,1024*1024)
    digest=hashlib.new(algorithm,path.read_bytes()).hexdigest()
    if expected and digest.lower()!=expected.lower(): raise RuntimeError('Checksum mismatch '+filename)
    receipts.append({'url':url,'file':filename,'bytes':path.stat().st_size,algorithm:digest})
    print('Verified download '+filename+' '+str(path.stat().st_size),flush=True)
    return path
def extract(archive,destination,strip=False):
    destination=destination.resolve();destination.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        for entry in z.infolist():
            parts=Path(entry.filename).parts[1:] if strip else Path(entry.filename).parts
            if not parts:continue
            target=destination.joinpath(*parts).resolve()
            if not target.is_relative_to(destination):raise RuntimeError('Unsafe ZIP path')
            if entry.is_dir():target.mkdir(parents=True,exist_ok=True)
            else:
                target.parent.mkdir(parents=True,exist_ok=True)
                with z.open(entry) as source,target.open('wb') as output:shutil.copyfileobj(source,output)
templates=build/'templates';templates.mkdir(exist_ok=True)
if not (templates/'web_nothreads_release.zip').exists() or not (templates/'android_release.apk').exists():
    with zipfile.ZipFile(RemoteZip(URL)) as z:
        names=z.namelist()
        print('Available mobile templates '+str([x for x in names if 'web' in x or 'android' in x]),flush=True)
        for filename in ['web_nothreads_release.zip','android_release.apk']:
            target=templates/filename
            if target.exists():continue
            name=next(x for x in names if x.endswith('/'+filename))
            with z.open(name) as source,target.open('wb') as output:shutil.copyfileobj(source,output,1024*1024)
            receipts.append({'url':URL,'member':name,'bytes':target.stat().st_size,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'crc_verified':True})
            print('Official template '+filename,flush=True)
jdk=build/'jdk17'
if not (jdk/'bin/java.exe').exists():
    try:
        packages=json.loads(get('https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse'))
        package=packages[0]['binary']['package']
        archive=download(package['link'],package['name'],package['checksum'])
    except urllib.error.HTTPError:
        url='https://cdn.azul.com/zulu/bin/zulu17.68.203-ca-jdk17.0.20.1-win_x64.zip'
        checksum=get(url+'.sha256').decode().split()[0]
        archive=download(url,url.rsplit('/',1)[-1],checksum)
    extract(archive,jdk,strip=True)
sdk=build/'android-sdk'
repository=ET.fromstring(get('https://dl.google.com/android/repository/repository2-1.xml'))
def children(element,name):return [x for x in element if x.tag.rsplit('}',1)[-1]==name]
def child(element,name):return next(iter(children(element,name)),None)
packages={x.attrib['path']:x for x in repository.iter() if x.tag.rsplit('}',1)[-1]=='remotePackage'}
tools_version=next(x for x in ['35.0.1','35.0.0','36.0.0'] if 'build-tools;'+x in packages)
for key,destination,marker in [('build-tools;'+tools_version,sdk/'build-tools'/tools_version,'apksigner.bat'),('platform-tools',sdk/'platform-tools','adb.exe'),('platforms;android-35',sdk/'platforms/android-35','android.jar')]:
    if (destination/marker).exists():continue
    archives=child(packages[key],'archives')
    archive=next(x for x in children(archives,'archive') if child(x,'host-os') is None or child(x,'host-os').text=='windows')
    complete=child(archive,'complete');url=child(complete,'url').text
    checksum=child(complete,'checksum')
    filename=url.rsplit('/',1)[-1]
    path=download('https://dl.google.com/android/repository/'+url,filename,checksum.text,checksum.attrib.get('type','sha1'))
    extract(path,destination,strip=True)
signing=build/'android-signing';signing.mkdir(exist_ok=True)
credentials=signing/'release-signing.json'
keystore=signing/'zhongrizi.keystore'
if not credentials.exists():credentials.write_text(json.dumps({'alias':'zhongrizi','password':secrets.token_urlsafe(32)}),encoding='utf8')
private=json.loads(credentials.read_text(encoding='utf8'))
if not keystore.exists():
    env=os.environ.copy();env['ZRZ_SIGN_PASSWORD']=private['password']
    subprocess.run([str(jdk/'bin/keytool.exe'),'-genkeypair','-keystore',str(keystore),'-storepass:env','ZRZ_SIGN_PASSWORD','-keypass:env','ZRZ_SIGN_PASSWORD','-alias',private['alias'],'-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=ZhongRiZi, O=ZhongRiZi, C=CN'],env=env,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
receipt={'downloads':receipts,'jdk':str(jdk),'sdk':str(sdk),'build_tools':tools_version,'keystore':str(keystore),'credentials_stay_local':True}
(project/'artifacts/quality-20261014/mobile-toolchain.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf8')
print('MOBILE_TOOLCHAIN_READY',flush=True)
