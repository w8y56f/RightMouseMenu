import plistlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
out = root / 'RightMouseMenu.xcodeproj' / 'project.pbxproj'
out.parent.mkdir(exist_ok=True)
objects = {}
i = 0
def uid():
    global i
    i += 1
    return f'{i:024X}'
def obj(**kwargs):
    k = uid(); objects[k] = kwargs; return k

def fileref(path, kind='sourcecode.swift', tree='<group>'):
    return obj(isa='PBXFileReference', lastKnownFileType=kind, path=path, sourceTree=tree)
def buildfile(ref, **kwargs):
    return obj(isa='PBXBuildFile', fileRef=ref, **kwargs)
def phase(kind, files, **kwargs):
    return obj(isa=kind, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0, **kwargs)

def configs(settings):
    ids=[]
    for name in ['Debug','Release']:
        d=dict(settings)
        d['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone' if name == 'Debug' else '-O'
        ids.append(obj(isa='XCBuildConfiguration', name=name, buildSettings=d))
    return obj(isa='XCConfigurationList', buildConfigurations=ids, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')

appfiles=['Sources/RightMouseMenu/RightMouseMenuApp.swift','Sources/RightMouseMenu/SettingsRootView.swift','Sources/RightMouseMenu/MenuActions.swift','Sources/RightMouseMenu/OfficeDocument.swift','Sources/Shared/SharedSettings.swift']
extfiles=['Sources/FinderExtension/FinderExtension.swift','Sources/Shared/SharedSettings.swift']
refs={p:fileref(p) for p in sorted(set(appfiles+extfiles))}
app_product=fileref('RightMouseMenu.app','wrapper.application','BUILT_PRODUCTS_DIR')
ext_product=fileref('RightMouseMenuFinderSync.appex','wrapper.app-extension','BUILT_PRODUCTS_DIR')
icon_ref=fileref('RightMouseMenu.icns','image.icns')
localization_ref=fileref('Resources/zh-Hans.lproj','folder')
template_ref=fileref('Resources/Templates','folder')
app_sources=phase('PBXSourcesBuildPhase',[buildfile(refs[p]) for p in appfiles])
ext_sources=phase('PBXSourcesBuildPhase',[buildfile(refs[p]) for p in extfiles])
ext_embed=phase('PBXCopyFilesBuildPhase',[buildfile(ext_product, settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})], dstPath='', dstSubfolderSpec=13, name='Embed App Extensions')
# Records the git commit in the built Info.plist (GitRevision), with " - dirty" when the tree has uncommitted changes.
revision_script = r'''set -eu
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
REV=""
if command -v git >/dev/null 2>&1 && git -C "${SRCROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  REV=$(git -C "${SRCROOT}" rev-parse --short HEAD 2>/dev/null || true)
  if [ -n "$REV" ] && [ -n "$(git -C "${SRCROOT}" status --porcelain 2>/dev/null)" ]; then REV="$REV - dirty"; fi
fi
/usr/libexec/PlistBuddy -c "Set :GitRevision \"$REV\"" "$PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :GitRevision string \"$REV\"" "$PLIST"
'''
revision_phase=obj(isa='PBXShellScriptBuildPhase',buildActionMask=2147483647,files=[],inputPaths=[],outputPaths=[],runOnlyForDeploymentPostprocessing=0,shellPath='/bin/sh',shellScript=revision_script,name='Record Git Revision',alwaysOutOfDate=1)
app_resources=phase('PBXResourcesBuildPhase',[buildfile(icon_ref),buildfile(localization_ref),buildfile(template_ref)])
ext_resources=phase('PBXResourcesBuildPhase',[buildfile(localization_ref)])
common={'MACOSX_DEPLOYMENT_TARGET':'15.0','SWIFT_VERSION':'6.0','SWIFT_STRICT_CONCURRENCY':'minimal','SDKROOT':'macosx','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','ENABLE_APP_SANDBOX':'NO','ALWAYS_SEARCH_USER_PATHS':'NO'}
app_cfg=configs({**common,'PRODUCT_BUNDLE_IDENTIFIER':'com.stone.rightmousemenu','PRODUCT_NAME':'RightMouseMenu','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_FILE':'Config/App-Info.plist','INFOPLIST_KEY_CFBundleDisplayName':'RightMouseMenu','INFOPLIST_KEY_CFBundleIconFile':'RightMouseMenu.icns','INFOPLIST_KEY_NSAppleEventsUsageDescription':'RightMouseMenu shows file information in Finder and opens terminals in the folder you choose.','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.utilities','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1','CODE_SIGN_ENTITLEMENTS':'Config/App.entitlements','SWIFT_EMIT_LOC_STRINGS':'YES'})
ext_cfg=configs({**common,'PRODUCT_BUNDLE_IDENTIFIER':'com.stone.rightmousemenu.findersync','PRODUCT_NAME':'RightMouseMenuFinderSync','INFOPLIST_FILE':'Config/FinderExtension-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/Extension.entitlements','ENABLE_APP_SANDBOX':'YES','SKIP_INSTALL':'YES','MARKETING_VERSION':'0.1.0','CURRENT_PROJECT_VERSION':'1'})
ext_target=obj(isa='PBXNativeTarget',name='RightMouseMenuFinderSync',productName='RightMouseMenuFinderSync',productReference=ext_product,productType='com.apple.product-type.app-extension',buildConfigurationList=ext_cfg,buildPhases=[ext_sources,ext_resources],buildRules=[],dependencies=[])
proxy=obj(isa='PBXContainerItemProxy',containerPortal='PROJECT',proxyType=1,remoteGlobalIDString=ext_target,remoteInfo='RightMouseMenuFinderSync')
dep=obj(isa='PBXTargetDependency',target=ext_target,targetProxy=proxy)
app_target=obj(isa='PBXNativeTarget',name='RightMouseMenu',productName='RightMouseMenu',productReference=app_product,productType='com.apple.product-type.application',buildConfigurationList=app_cfg,buildPhases=[app_sources,app_resources,ext_embed,revision_phase],buildRules=[],dependencies=[dep])
project_cfg=configs({'MACOSX_DEPLOYMENT_TARGET':'15.0','SDKROOT':'macosx','SWIFT_VERSION':'6.0'})
products=obj(isa='PBXGroup',children=[app_product,ext_product],name='Products',sourceTree='<group>')
main=obj(isa='PBXGroup',children=list(refs.values())+[icon_ref,localization_ref,template_ref,products],sourceTree='<group>')
project=obj(isa='PBXProject',attributes={'LastUpgradeCheck':'2600','TargetAttributes':{app_target:{'CreatedOnToolsVersion':'26.0'},ext_target:{'CreatedOnToolsVersion':'26.0'}}},buildConfigurationList=project_cfg,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main,productRefGroup=products,projectDirPath='',projectRoot='',targets=[app_target,ext_target])
objects[proxy]['containerPortal']=project
content={'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project}
out.write_bytes(plistlib.dumps(content,fmt=plistlib.FMT_XML,sort_keys=False))
print(out)
