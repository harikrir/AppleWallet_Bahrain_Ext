var fs = require('fs');
var path = require('path');
var Q = require('q'); 
var pluginID = null;


function redError(message) {
    return new Error(pluginID + '" \x1b[1m\x1b[31m' + message + '\x1b[0m');
}

function cloneFile(source, target) {
  var targetFile = target;

  if (fs.existsSync(target)) {
    if (fs.lstatSync(target).isDirectory()) {
      targetFile = path.join(target, path.basename(source));
    }
  }

  fs.writeFileSync(targetFile, fs.readFileSync(source));
}

function copyExtensionFolders(source, target) {
  var files = [];

  var targetFolder = path.join(target, path.basename(source));
  if (!fs.existsSync(targetFolder)) {
    fs.mkdirSync(targetFolder);
  }

  if (fs.lstatSync(source).isDirectory()) {
    files = fs.readdirSync(source);
    files.forEach(function(file) {
      var curSource = path.join(source, file);
      if (fs.lstatSync(curSource).isDirectory()) {
        copyExtensionFolders(curSource, targetFolder);
      } else {
        cloneFile(curSource, targetFolder);
      }
    });
  }
}

function findXCodeproject(context, callback) {
  var iosFolder = context.opts.cordova.project
    ? context.opts.cordova.project.root
    : path.join(context.opts.projectRoot, 'platforms','ios');
  fs.readdir(iosFolder, function(err, data) {
    var projectFolder;
    var projectName;
    // Find the project folder by looking for *.xcodeproj
    if (data && data.length) {
      data.forEach(function(folder) {
        if (folder.match(/\.xcodeproj$/)) {
          projectFolder = path.join(iosFolder, folder);
          projectName = path.basename(folder, '.xcodeproj');
        }
      });
    }

    if (!projectFolder || !projectName) {
      throw redError('Could not find an .xcodeproj folder in: ' + iosFolder);
    }

    if (err) {
      throw redError(err);
    }

    callback(projectFolder, projectName);
  });
}

module.exports = function(context) {
  var deferral = Q.defer();
  pluginID = context.opts.plugin.id

  findXCodeproject(context, function(projectFolder, projectName) {

    var UIExtension = path.join(context.opts.projectRoot, 'plugins', pluginID, 'src', 'ios', 'WalletExtensionUI');
    if (!fs.existsSync(UIExtension)) {
      throw redError('Missing extension project folder in ' + UIExtension + '.');
    }

    copyExtensionFolders(UIExtension, path.join(context.opts.projectRoot, 'platforms', 'ios'));
	
	var NonUIUIExtension = path.join(context.opts.projectRoot, 'plugins', pluginID, 'src', 'ios', 'WalletExtension');
    if (!fs.existsSync(NonUIUIExtension)) {
      throw redError('Missing extension project folder in ' + NonUIUIExtension + '.');
    }

    copyExtensionFolders(NonUIUIExtension, path.join(context.opts.projectRoot, 'platforms', 'ios'));
	
    deferral.resolve();
  });

  return deferral.promise;
};
