"""Generate the checked-in, dependency-free Xcode demo project."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Examples/ZuchiniDemo/ZuchiniDemo.xcodeproj"
objects = {}

def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def obj(object_label, isa, **kwargs):
    key = ident(object_label)
    objects[key] = {"isa": isa, **kwargs}
    return key

def encode(value, depth=0):
    indent = "\t" * depth
    if isinstance(value, dict):
        body = "\n".join(f'{indent}\t{json.dumps(str(k))} = {encode(v, depth+1)};' for k, v in value.items())
        return "{\n" + body + "\n" + indent + "}"
    if isinstance(value, list):
        return "(\n" + "\n".join(f'{indent}\t{encode(v, depth+1)},' for v in value) + "\n" + indent + ")"
    return json.dumps(str(value))

source = obj("source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="ZuchiniDemoApp.swift", sourceTree="<group>")
product = obj("product", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex="0", path="ZuchiniDemo.app", sourceTree="BUILT_PRODUCTS_DIR")
source_build = obj("source-build", "PBXBuildFile", fileRef=source)
package = obj("local-package", "XCLocalSwiftPackageReference", relativePath="../..")
dependencies = []
framework_files = []
for name in ["ZuchiniCore", "ZuchiniMenu"]:
    dep = obj(f"package-{name}", "XCSwiftPackageProductDependency", package=package, productName=name)
    dependencies.append(dep)
    framework_files.append(obj(f"link-{name}", "PBXBuildFile", productRef=dep))
sources = obj("sources-phase", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[source_build], runOnlyForDeploymentPostprocessing="0")
frameworks = obj("frameworks-phase", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=framework_files, runOnlyForDeploymentPostprocessing="0")
resources = obj("resources-phase", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=[], runOnlyForDeploymentPostprocessing="0")
products = obj("products-group", "PBXGroup", children=[product], name="Products", sourceTree="<group>")
group = obj("main-group", "PBXGroup", children=[source, products], sourceTree="<group>")
project_configs = []
target_configs = []
for mode in ["Debug", "Release"]:
    settings = {
        "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "16.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)" if mode == "Debug" else "$(inherited)",
    }
    project_configs.append(obj(f"project-{mode}", "XCBuildConfiguration", name=mode, buildSettings=settings))
    app_settings = {
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "MARKETING_VERSION": "0.1.0",
        "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "Zuchini",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.example.zuchini.demo", "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    }
    target_configs.append(obj(f"target-{mode}", "XCBuildConfiguration", name=mode, buildSettings=app_settings))
project_list = obj("project-config-list", "XCConfigurationList", buildConfigurations=project_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
target_list = obj("target-config-list", "XCConfigurationList", buildConfigurations=target_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
target = obj("app-target", "PBXNativeTarget", buildConfigurationList=target_list, buildPhases=[sources, frameworks, resources], buildRules=[], dependencies=[], name="ZuchiniDemo", packageProductDependencies=dependencies, productName="ZuchiniDemo", productReference=product, productType="com.apple.product-type.application")
project = obj("project", "PBXProject", attributes={"LastUpgradeCheck": "1500", "BuildIndependentTargetsInParallel": "YES"}, buildConfigurationList=project_list, compatibilityVersion="Xcode 14.0", developmentRegion="en", hasScannedForEncodings="0", knownRegions=["en", "Base"], mainGroup=group, packageReferences=[package], productRefGroup=products, projectDirPath="", projectRoot="", targets=[target])
ui_source = obj("ui-source", "PBXFileReference", lastKnownFileType="sourcecode.swift", path="ZuchiniUITests.swift", sourceTree="<group>")
ui_product = obj("ui-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", includeInIndex="0", path="ZuchiniUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
ui_build = obj("ui-source-build", "PBXBuildFile", fileRef=ui_source)
ui_sources = obj("ui-sources-phase", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=[ui_build], runOnlyForDeploymentPostprocessing="0")
ui_configs = []
for mode in ["Debug", "Release"]:
    ui_configs.append(obj(f"ui-{mode}", "XCBuildConfiguration", name=mode, buildSettings={
        "GENERATE_INFOPLIST_FILE": "YES", "PRODUCT_BUNDLE_IDENTIFIER": "com.example.zuchini.uitests",
        "PRODUCT_NAME": "$(TARGET_NAME)", "TEST_TARGET_NAME": "ZuchiniDemo", "TARGETED_DEVICE_FAMILY": "1,2",
        "CODE_SIGN_STYLE": "Automatic", "SWIFT_VERSION": "5.0",
    }))
ui_list = obj("ui-config-list", "XCConfigurationList", buildConfigurations=ui_configs, defaultConfigurationIsVisible="0", defaultConfigurationName="Release")
proxy = obj("ui-proxy", "PBXContainerItemProxy", containerPortal=project, proxyType="1", remoteGlobalIDString=target, remoteInfo="ZuchiniDemo")
ui_dependency = obj("ui-dependency", "PBXTargetDependency", target=target, targetProxy=proxy)
ui_target = obj("ui-target", "PBXNativeTarget", buildConfigurationList=ui_list, buildPhases=[ui_sources], buildRules=[], dependencies=[ui_dependency], name="ZuchiniUITests", productName="ZuchiniUITests", productReference=ui_product, productType="com.apple.product-type.bundle.ui-testing")
objects[group]["children"].append(ui_source)
objects[products]["children"].append(ui_product)
objects[project]["targets"].append(ui_target)
objects[project]["attributes"]["TargetAttributes"] = {ui_target: {"TestTargetID": target}}

document = {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects, "rootObject": project}
PROJECT.mkdir(parents=True, exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode(document) + "\n", encoding="utf-8")

scheme = ET.Element("Scheme", LastUpgradeVersion="1500", version="1.3")
build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES", buildImplicitDependencies="YES")
entries = ET.SubElement(build, "BuildActionEntries")
entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES", buildForRunning="YES", buildForProfiling="YES", buildForArchiving="YES", buildForAnalyzing="YES")
def reference(parent):
    ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=target, BuildableName="ZuchiniDemo.app", BlueprintName="ZuchiniDemo", ReferencedContainer="container:ZuchiniDemo.xcodeproj")
reference(entry)
test_action = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", shouldUseLaunchSchemeArgsEnv="YES")
testables = ET.SubElement(test_action, "Testables")
testable = ET.SubElement(testables, "TestableReference", skipped="NO")
ET.SubElement(testable, "BuildableReference", BuildableIdentifier="primary", BlueprintIdentifier=ui_target, BuildableName="ZuchiniUITests.xctest", BlueprintName="ZuchiniUITests", ReferencedContainer="container:ZuchiniDemo.xcodeproj")
launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug", selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB", selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB", launchStyle="0", useCustomWorkingDirectory="NO", ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES", debugServiceExtension="internal", allowLocationSimulation="YES")
reference(ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0"))
profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release", shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="", useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
reference(ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0"))
ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release", revealArchiveInOrganizer="YES")
ET.indent(scheme, space="  ")
scheme_path = PROJECT / "xcshareddata/xcschemes/ZuchiniDemo.xcscheme"
scheme_path.parent.mkdir(parents=True, exist_ok=True)
ET.ElementTree(scheme).write(scheme_path, encoding="utf-8", xml_declaration=True)
print("Generated", PROJECT.relative_to(ROOT))
