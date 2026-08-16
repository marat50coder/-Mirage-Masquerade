#!/usr/bin/env python3
"""One-shot injector: adds the MasqueMediaService NSE target to project.pbxproj,
wires Runner entitlements, and adds GoogleService-Info.plist + PrivacyInfo.xcprivacy
to the Runner Resources phase. Binary-safe (no BOM, LF preserved), fresh UUIDs.

Idempotent guard: refuses to run twice (checks for the NSE target name).
"""
import re
import secrets

PBX = 'ios/Runner.xcodeproj/project.pbxproj'
TEAM = 'B5DB7D3VCH'
NSE_NAME = 'MasqueMediaService'
NSE_BUNDLE = 'com.miragemasque.masqueradegame.NotificationService'

# Runner anchors (from the existing project).
RUNNER_TARGET = '97C146ED1CF9000F007C117D'
RUNNER_GROUP = '97C146F01CF9000F007C117D'
MAIN_GROUP = '97C146E51CF9000F007C117D'
PROJECT_OBJ = '97C146E61CF9000F007C117D'
PRODUCTS_GROUP = '97C146EF1CF9000F007C117D'
THIN_BINARY = '3B06AD1E1E4923F5004D2608'
RUNNER_RESOURCES = '97C146EC1CF9000F007C117D'
RUNNER_CFG = ['97C147061CF9000F007C117D', '97C147071CF9000F007C117D',
              '249021D4217E4FDB00AE95B9']  # Debug / Release / Profile


def uid():
    return secrets.token_hex(12).upper()


def main():
    raw = open(PBX, 'rb').read().decode('utf-8')
    txt = raw.replace('\r\n', '\n')

    if NSE_NAME in txt:
        print('NSE already present — aborting to avoid double-inject.')
        return

    # Fresh UUIDs for every NSE object.
    u = {k: uid() for k in [
        'nse_target', 'nse_group', 'nse_cfg_list', 'nse_dbg', 'nse_rel', 'nse_prof',
        'nse_product', 'svc_fileref', 'plist_fileref', 'svc_buildfile',
        'nse_sources', 'nse_frameworks', 'nse_resources',
        'embed_phase', 'appex_embed_buildfile', 'dep', 'proxy',
        'gsi_fileref', 'gsi_buildfile', 'priv_fileref', 'priv_buildfile',
        'ent_fileref',
    ]}

    # ── 1. PBXBuildFile entries ────────────────────────────────────────────
    build_files = (
        f"\t\t{u['svc_buildfile']} /* NotificationService.swift in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {u['svc_fileref']} /* NotificationService.swift */; }};\n"
        f"\t\t{u['appex_embed_buildfile']} /* {NSE_NAME}.appex in Embed Foundation Extensions */ = "
        f"{{isa = PBXBuildFile; fileRef = {u['nse_product']} /* {NSE_NAME}.appex */; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};\n"
        f"\t\t{u['gsi_buildfile']} /* GoogleService-Info.plist in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {u['gsi_fileref']} /* GoogleService-Info.plist */; }};\n"
        f"\t\t{u['priv_buildfile']} /* PrivacyInfo.xcprivacy in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {u['priv_fileref']} /* PrivacyInfo.xcprivacy */; }};\n"
    )
    txt = txt.replace('/* End PBXBuildFile section */',
                      build_files + '/* End PBXBuildFile section */')

    # ── 2. PBXContainerItemProxy (Runner -> NSE dependency) ────────────────
    proxy = (
        f"\t\t{u['proxy']} /* PBXContainerItemProxy */ = {{\n"
        f"\t\t\tisa = PBXContainerItemProxy;\n"
        f"\t\t\tcontainerPortal = {PROJECT_OBJ} /* Project object */;\n"
        f"\t\t\tproxyType = 1;\n"
        f"\t\t\tremoteGlobalIDString = {u['nse_target']};\n"
        f"\t\t\tremoteInfo = {NSE_NAME};\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXContainerItemProxy section */',
                      proxy + '/* End PBXContainerItemProxy section */')

    # ── 3. PBXCopyFilesBuildPhase (Embed Foundation Extensions) ────────────
    embed = (
        f"\t\t{u['embed_phase']} /* Embed Foundation Extensions */ = {{\n"
        f"\t\t\tisa = PBXCopyFilesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tdstPath = \"\";\n"
        f"\t\t\tdstSubfolderSpec = 13;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{u['appex_embed_buildfile']} /* {NSE_NAME}.appex in Embed Foundation Extensions */,\n"
        f"\t\t\t);\n"
        f"\t\t\tname = \"Embed Foundation Extensions\";\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXCopyFilesBuildPhase section */',
                      embed + '/* End PBXCopyFilesBuildPhase section */')

    # ── 4. PBXFileReference entries ────────────────────────────────────────
    file_refs = (
        f"\t\t{u['svc_fileref']} /* NotificationService.swift */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = sourcecode.swift; path = NotificationService.swift; sourceTree = \"<group>\"; }};\n"
        f"\t\t{u['plist_fileref']} /* Info.plist */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};\n"
        f"\t\t{u['nse_product']} /* {NSE_NAME}.appex */ = {{isa = PBXFileReference; "
        f"explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = {NSE_NAME}.appex; "
        f"sourceTree = BUILT_PRODUCTS_DIR; }};\n"
        f"\t\t{u['gsi_fileref']} /* GoogleService-Info.plist */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = text.plist.xml; path = \"GoogleService-Info.plist\"; sourceTree = \"<group>\"; }};\n"
        f"\t\t{u['priv_fileref']} /* PrivacyInfo.xcprivacy */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = text.plist.xml; path = PrivacyInfo.xcprivacy; sourceTree = \"<group>\"; }};\n"
        f"\t\t{u['ent_fileref']} /* Runner.entitlements */ = {{isa = PBXFileReference; "
        f"lastKnownFileType = text.plist.entitlements; path = Runner.entitlements; sourceTree = \"<group>\"; }};\n"
    )
    txt = txt.replace('/* End PBXFileReference section */',
                      file_refs + '/* End PBXFileReference section */')

    # ── 5. PBXFrameworksBuildPhase (NSE, empty — pods add later) ────────────
    nse_fw = (
        f"\t\t{u['nse_frameworks']} /* Frameworks */ = {{\n"
        f"\t\t\tisa = PBXFrameworksBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXFrameworksBuildPhase section */',
                      nse_fw + '/* End PBXFrameworksBuildPhase section */')

    # ── 6. PBXGroup: NSE group + add files to Runner group + main group ─────
    nse_group = (
        f"\t\t{u['nse_group']} /* {NSE_NAME} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"\t\t\t\t{u['svc_fileref']} /* NotificationService.swift */,\n"
        f"\t\t\t\t{u['plist_fileref']} /* Info.plist */,\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = {NSE_NAME};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXGroup section */',
                      nse_group + '/* End PBXGroup section */')

    # Add entitlements + GoogleService-Info + PrivacyInfo to the Runner group.
    runner_group_anchor = (
        f"\t\t{RUNNER_GROUP} /* Runner */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
    )
    runner_group_add = runner_group_anchor + (
        f"\t\t\t\t{u['gsi_fileref']} /* GoogleService-Info.plist */,\n"
        f"\t\t\t\t{u['priv_fileref']} /* PrivacyInfo.xcprivacy */,\n"
        f"\t\t\t\t{u['ent_fileref']} /* Runner.entitlements */,\n"
    )
    assert runner_group_anchor in txt, 'Runner group anchor not found'
    txt = txt.replace(runner_group_anchor, runner_group_add)

    # Add the NSE group to the main group (sibling of Runner).
    main_group_anchor = f"\t\t\t\t{RUNNER_GROUP} /* Runner */,\n"
    txt = txt.replace(
        main_group_anchor,
        main_group_anchor + f"\t\t\t\t{u['nse_group']} /* {NSE_NAME} */,\n",
        1,
    )

    # Add the .appex to the Products group.
    products_anchor = (
        f"\t\t{PRODUCTS_GROUP} /* Products */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
    )
    txt = txt.replace(
        products_anchor,
        products_anchor + f"\t\t\t\t{u['nse_product']} /* {NSE_NAME}.appex */,\n",
    )

    # ── 7. PBXNativeTarget (NSE) + add Embed phase + dependency to Runner ───
    nse_target = (
        f"\t\t{u['nse_target']} /* {NSE_NAME} */ = {{\n"
        f"\t\t\tisa = PBXNativeTarget;\n"
        f"\t\t\tbuildConfigurationList = {u['nse_cfg_list']} /* Build configuration list for PBXNativeTarget \"{NSE_NAME}\" */;\n"
        f"\t\t\tbuildPhases = (\n"
        f"\t\t\t\t{u['nse_sources']} /* Sources */,\n"
        f"\t\t\t\t{u['nse_frameworks']} /* Frameworks */,\n"
        f"\t\t\t\t{u['nse_resources']} /* Resources */,\n"
        f"\t\t\t);\n"
        f"\t\t\tbuildRules = (\n\t\t\t);\n"
        f"\t\t\tdependencies = (\n\t\t\t);\n"
        f"\t\t\tname = {NSE_NAME};\n"
        f"\t\t\tproductName = {NSE_NAME};\n"
        f"\t\t\tproductReference = {u['nse_product']} /* {NSE_NAME}.appex */;\n"
        f"\t\t\tproductType = \"com.apple.product-type.app-extension\";\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXNativeTarget section */',
                      nse_target + '/* End PBXNativeTarget section */')

    # Insert Embed phase into Runner buildPhases, right before Thin Binary.
    thin_line = f"\t\t\t\t{THIN_BINARY} /* Thin Binary */,\n"
    assert thin_line in txt, 'Thin Binary phase not found in Runner'
    txt = txt.replace(
        thin_line,
        f"\t\t\t\t{u['embed_phase']} /* Embed Foundation Extensions */,\n" + thin_line,
    )

    # Add dependency block to Runner target.
    runner_deps_anchor = (
        f"\t\t{RUNNER_TARGET} /* Runner */ = {{\n"
    )
    # inject dependency into Runner's (currently empty) dependencies = ( )
    runner_block_start = txt.index(runner_deps_anchor)
    runner_block = txt[runner_block_start:runner_block_start + 900]
    new_runner_block = runner_block.replace(
        'dependencies = (\n\t\t\t);',
        f"dependencies = (\n\t\t\t\t{u['dep']} /* PBXTargetDependency */,\n\t\t\t);",
        1,
    )
    txt = txt[:runner_block_start] + new_runner_block + txt[runner_block_start + 900:]

    # ── 8. PBXProject: add NSE to targets + TargetAttributes ───────────────
    txt = txt.replace(
        f"\t\t\t\t{RUNNER_TARGET} /* Runner */,\n\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n",
        f"\t\t\t\t{RUNNER_TARGET} /* Runner */,\n"
        f"\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
        f"\t\t\t\t{u['nse_target']} /* {NSE_NAME} */,\n",
    )
    txt = txt.replace(
        '\t\t\t\t97C146ED1CF9000F007C117D = {\n'
        '\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n'
        '\t\t\t\t\tLastSwiftMigration = 1100;\n'
        '\t\t\t\t};\n',
        '\t\t\t\t97C146ED1CF9000F007C117D = {\n'
        '\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n'
        '\t\t\t\t\tLastSwiftMigration = 1100;\n'
        '\t\t\t\t};\n'
        f'\t\t\t\t{u["nse_target"]} = {{\n'
        '\t\t\t\t\tCreatedOnToolsVersion = 16.0;\n'
        '\t\t\t\t};\n',
    )

    # ── 9. PBXResourcesBuildPhase: NSE (empty) + add GSI/Priv to Runner ─────
    nse_res = (
        f"\t\t{u['nse_resources']} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXResourcesBuildPhase section */',
                      nse_res + '/* End PBXResourcesBuildPhase section */')

    runner_res_anchor = (
        f"\t\t{RUNNER_RESOURCES} /* Resources */ = {{\n"
        f"\t\t\tisa = PBXResourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
    )
    assert runner_res_anchor in txt, 'Runner resources anchor not found'
    txt = txt.replace(
        runner_res_anchor,
        runner_res_anchor
        + f"\t\t\t\t{u['gsi_buildfile']} /* GoogleService-Info.plist in Resources */,\n"
        + f"\t\t\t\t{u['priv_buildfile']} /* PrivacyInfo.xcprivacy in Resources */,\n",
    )

    # ── 10. PBXSourcesBuildPhase (NSE) ─────────────────────────────────────
    nse_src = (
        f"\t\t{u['nse_sources']} /* Sources */ = {{\n"
        f"\t\t\tisa = PBXSourcesBuildPhase;\n"
        f"\t\t\tbuildActionMask = 2147483647;\n"
        f"\t\t\tfiles = (\n"
        f"\t\t\t\t{u['svc_buildfile']} /* NotificationService.swift in Sources */,\n"
        f"\t\t\t);\n"
        f"\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXSourcesBuildPhase section */',
                      nse_src + '/* End PBXSourcesBuildPhase section */')

    # ── 11. PBXTargetDependency ────────────────────────────────────────────
    dep = (
        f"\t\t{u['dep']} /* PBXTargetDependency */ = {{\n"
        f"\t\t\tisa = PBXTargetDependency;\n"
        f"\t\t\ttarget = {u['nse_target']} /* {NSE_NAME} */;\n"
        f"\t\t\ttargetProxy = {u['proxy']} /* PBXContainerItemProxy */;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End PBXTargetDependency section */',
                      dep + '/* End PBXTargetDependency section */')

    # ── 12. XCBuildConfiguration (NSE Debug/Release/Profile) ───────────────
    def nse_cfg(cfg_uid, name, extra):
        return (
            f"\t\t{cfg_uid} /* {name} */ = {{\n"
            f"\t\t\tisa = XCBuildConfiguration;\n"
            f"\t\t\tbuildSettings = {{\n"
            f"\t\t\t\tCODE_SIGN_STYLE = Automatic;\n"
            f"\t\t\t\tCURRENT_PROJECT_VERSION = 2;\n"
            f"\t\t\t\tDEVELOPMENT_TEAM = {TEAM};\n"
            f"\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n"
            f"\t\t\t\tINFOPLIST_FILE = {NSE_NAME}/Info.plist;\n"
            f"\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;\n"
            f"\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n"
            f"\t\t\t\t\t\"$(inherited)\",\n"
            f"\t\t\t\t\t\"@executable_path/Frameworks\",\n"
            f"\t\t\t\t\t\"@executable_path/../../Frameworks\",\n"
            f"\t\t\t\t);\n"
            f"\t\t\t\tMARKETING_VERSION = 1.0.0;\n"
            f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {NSE_BUNDLE};\n"
            f"\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
            f"\t\t\t\tSKIP_INSTALL = YES;\n"
            f"\t\t\t\tSWIFT_VERSION = 5.0;\n"
            f"\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
            f"{extra}"
            f"\t\t\t}};\n"
            f"\t\t\tname = {name};\n"
            f"\t\t}};\n"
        )

    dbg_extra = ("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;\n"
                 "\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;\n"
                 "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";\n")
    rel_extra = ("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";\n"
                 "\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";\n")
    nse_cfgs = (
        nse_cfg(u['nse_dbg'], 'Debug', dbg_extra)
        + nse_cfg(u['nse_rel'], 'Release', rel_extra)
        + nse_cfg(u['nse_prof'], 'Profile', rel_extra)
    )
    txt = txt.replace('/* End XCBuildConfiguration section */',
                      nse_cfgs + '/* End XCBuildConfiguration section */')

    # ── 13. XCConfigurationList (NSE) ──────────────────────────────────────
    nse_cfg_list = (
        f"\t\t{u['nse_cfg_list']} /* Build configuration list for PBXNativeTarget \"{NSE_NAME}\" */ = {{\n"
        f"\t\t\tisa = XCConfigurationList;\n"
        f"\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{u['nse_dbg']} /* Debug */,\n"
        f"\t\t\t\t{u['nse_rel']} /* Release */,\n"
        f"\t\t\t\t{u['nse_prof']} /* Profile */,\n"
        f"\t\t\t);\n"
        f"\t\t\tdefaultConfigurationIsVisible = 0;\n"
        f"\t\t\tdefaultConfigurationName = Release;\n"
        f"\t\t}};\n"
    )
    txt = txt.replace('/* End XCConfigurationList section */',
                      nse_cfg_list + '/* End XCConfigurationList section */')

    # ── 14. Runner configs: entitlements + team fix ────────────────────────
    for cfg in RUNNER_CFG:
        start = txt.index(f"\t\t{cfg} /* ")
        end = txt.index('name = ', start)
        block = txt[start:end]
        if 'CODE_SIGN_ENTITLEMENTS' not in block:
            block = block.replace(
                'buildSettings = {\n',
                'buildSettings = {\n'
                '\t\t\t\tCODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\n',
                1,
            )
        block = block.replace('DEVELOPMENT_TEAM = 63V23FXWWW;',
                              f'DEVELOPMENT_TEAM = {TEAM};')
        txt = txt[:start] + block + txt[end:]

    # Write back: no BOM, real tabs, LF.
    open(PBX, 'wb').write(txt.encode('utf-8'))
    print('NSE injected OK')


if __name__ == '__main__':
    main()
