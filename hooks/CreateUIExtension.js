var fs = require('fs');
var path = require('path');
var Q = require('q'); 
var pluginID = null;
var applicationGroup = "group.com.aub.mobilebanking";
var UI_Identifier = "com.aub.mobilebanking.phone.eg.UIExt";

function redError(message) {
    return new Error(pluginID + '" \x1b[1m\x1b[31m' + message + '\x1b[0m');
}

function replaceFile(filePath, preferences) {
    var content = fs.readFileSync(filePath, 'utf8');
    for (var i = 0; i < preferences.length; i++) {
        var pref = preferences[i];
        var regexp = new RegExp(pref.key, "g");
        content = content.replace(regexp, pref.value);
    }
    fs.writeFileSync(filePath, content);
}

function findXCodeproject(context, callback) {
    fs.readdir(iosFolder(context), function(err, data) {
        var projectFolder;
        var projectName;
        if (data && data.length) {
            data.forEach(function(folder) {
                if (folder.match(/\.xcodeproj$/)) {
                    projectFolder = path.join(iosFolder(context), folder);
                    projectName = path.basename(folder, '.xcodeproj');
                }
            });
        }

        if (!projectFolder || !projectName) {
            throw redError('Could not find an .xcodeproj folder in: ' + iosFolder(context));
        }

        if (err) {
            throw redError(err);
        }

        callback(projectFolder, projectName);
    });
}

function iosFolder(context) {
    return context.opts.cordova.project ?
        context.opts.cordova.project.root :
        path.join('platforms','ios');
}

function getPreferenceValue(configXml, name) {
    var value = configXml.match(new RegExp('name="' + name + '" value="(.*?)"', "i"));
    if (value && value[1]) {
        return value[1];
    } else {
        return null;
    }
}

function getCordovaParameter(configXml, variableName) {
    var variable;
    var arg = process.argv.filter(function(arg) {
        return arg.indexOf(variableName + '=') == 0;
    });
    if (arg.length >= 1) {
        variable = arg[0].split('=')[1];
    } else {
        variable = getPreferenceValue(configXml, variableName);
    }
    return variable;
}

function parsePbxProject(context, pbxProjectPath) {
    var xcode = require('xcode'); 
    console.log('🚨 Create UI Extension : parsePbxProject Location: ' + pbxProjectPath + '...');
    var pbxProject;
    if (context.opts.cordova.project) {
        pbxProject = context.opts.cordova.project.parseProjectFile(context.opts.projectRoot).xcode;
    } else {
        pbxProject = xcode.project(pbxProjectPath);
        pbxProject.parseSync();
    }
    return pbxProject;
}

function forEachWalletExtensionUIFile(context, callback) {
    var WalletExtensionUIFolder = path.join(iosFolder(context), 'WalletExtensionUI');
    fs.readdirSync(WalletExtensionUIFolder).forEach(function(name) {
        if (!/^\..*/.test(name)) {
            callback({
                name: name,
                path: path.join(WalletExtensionUIFolder, name),
                extension: path.extname(name)
            });
        }
    });
}

function projectPlistPath(context, projectName) {
    return path.join(iosFolder(context), projectName, projectName + '-Info.plist');
}

function projectPlistJson(context, projectName) {
    var plist = require('plist');
    var path = projectPlistPath(context, projectName);
    return plist.parse(fs.readFileSync(path, 'utf8'));
}

function getPreferences(context, configXml, projectName) {
    var plist = projectPlistJson(context, projectName);
    var group = applicationGroup;
    if (getCordovaParameter(configXml, 'GROUP_IDENTIFIER') !== "") {
        group = getCordovaParameter(configXml, 'IOS_GROUP_IDENTIFIER');
    }
    return [{
        key: '__DISPLAY_NAME__',
        value: projectName
    }, {
        key: '__BUNDLE_IDENTIFIER__',
        value: UI_Identifier
    }, {
        key: '__GROUP_IDENTIFIER__',
        value: group
    }, {
        key: '__BUNDLE_SHORT_VERSION_STRING__',
        value: plist.CFBundleShortVersionString
    }, {
        key: '__BUNDLE_VERSION__',
        value: plist.CFBundleVersion
    }];
}

function getWalletExtensionUIFiles(context) {
    var files = {
        source: [],
        plist: [],
        resource: []
    };
    var FILE_TYPES = {
        '.swift': 'source',
        '.plist': 'plist'
    };
    forEachWalletExtensionUIFile(context, function(file) {
        var fileType = FILE_TYPES[file.extension] || 'resource';
        files[fileType].push(file);
    });
    return files;
}


console.log('🚨 Create UI Extension : Adding target "' + pluginID + '/WalletExtensionUI" to XCode project');

module.exports = function(context) {
    var deferral = Q.defer();
    pluginID = context.opts.plugin.id;

    var configXml = fs.readFileSync(path.join(context.opts.projectRoot, 'config.xml'), 'utf-8');
    if (configXml) {
        configXml = configXml.substring(configXml.indexOf('<'));
    }

    findXCodeproject(context, function(projectFolder, projectName) {
        console.log('🚨 Create UI Extension :   - Folder containing your iOS project: ' + iosFolder(context));

        var pbxProjectPath = path.join(projectFolder, 'project.pbxproj');
        var pbxProject = parsePbxProject(context, pbxProjectPath);

        var files = getWalletExtensionUIFiles(context);

        var preferences = getPreferences(context, configXml, projectName);
        files.plist.concat(files.source).forEach(function(file) {
            replaceFile(file.path, preferences);
        });

        var target = pbxProject.pbxTargetByName('WalletExtensionUI');
        if (target) {
            console.log('🚨 Create UI Extension : WalletExtensionUI target already exists.');
        }

        if (!target) {
            target = pbxProject.addTarget('WalletExtensionUI', 'app_extension', 'WalletExtensionUI');
            pbxProject.addBuildPhase([], 'PBXSourcesBuildPhase', 'Sources', target.uuid);
            pbxProject.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', target.uuid);
        }

        var pbxGroupKey = pbxProject.findPBXGroupKey({
            name: 'WalletExtensionUI'
        });
        if (pbxProject) {
            console.log('🚨 Create UI Extension : WalletExtensionUI group already exists.');
        }
        if (!pbxGroupKey) {
            pbxGroupKey = pbxProject.pbxCreateGroup('WalletExtensionUI', 'WalletExtensionUI');
            var customTemplateKey = pbxProject.findPBXGroupKey({
                name: 'CustomTemplate'
            });
            pbxProject.addToPbxGroup(pbxGroupKey, customTemplateKey);
        }

        var frameworksBuildPhase = pbxProject.addBuildPhase([],'PBXFrameworksBuildPhase','Frameworks',target.uuid);
        if (frameworksBuildPhase) {
            console.log('🚨 Create UI Extension : Successfully added PBXFrameworksBuildPhase!', 'info');
        }

        pbxProject.addFramework('IntentsUI.framework', {target: target.uuid});
        pbxProject.addFramework('PassKit.framework', {target: target.uuid});
        pbxProject.addFramework('UIKit.framework', {target: target.uuid});
        
        files.plist.forEach(function(file) {
            pbxProject.addFile(file.name, pbxGroupKey);
        });

        files.source.forEach(function(file) {
            pbxProject.addSourceFile(file.name, {
                target: target.uuid
            }, pbxGroupKey);
        });

        files.resource.forEach(function(file) {
            pbxProject.addResourceFile(file.name, {
                target: target.uuid
            }, pbxGroupKey);
        });

        fs.writeFileSync(pbxProjectPath, pbxProject.writeSync());
        console.log('🚨 Create UI Extension : Added WalletExtensionUI to XCode project');

        deferral.resolve();
    });

    return deferral.promise;
};