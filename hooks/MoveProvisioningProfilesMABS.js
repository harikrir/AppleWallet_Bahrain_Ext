var fs = require('fs');
var path = require('path');
var Q = require('q');

console.log('📝 Copying Provisioning Profiles folder ...', 'start');

var copyFileSync = function (source, target) {
  var targetFile = target;

  if (fs.existsSync(target)) {
    if (fs.lstatSync(target).isDirectory()) {
      targetFile = path.join(target, path.basename(source));
    }
  }

  fs.writeFileSync(targetFile, fs.readFileSync(source));
};

var copyFolderRecursiveSync = function (source, targetFolder) {
  var files = [];

  if (fs.lstatSync(source).isDirectory()) {
    files = fs.readdirSync(source);
    files.forEach(function (file) {
      var curSource = path.join(source, file);
      if (fs.lstatSync(curSource).isDirectory()) {
        copyFolderRecursiveSync(curSource, targetFolder);
      } else {
        copyFileSync(curSource, targetFolder);
      }
      var targetFile = path.join(targetFolder, file);
      var fileExists = fs.existsSync(targetFile);
      if (fileExists) {
        console.log('📝 file ' + targetFile + ' copied with success', 'success');
      } else {
        console.log('file ' + targetFile + ' copied without success', 'error');
      }
    });
  }
};

function listDirectoryContents(directoryPath) {
  const files = fs.readdirSync(directoryPath);

  files.forEach(file => {
    const fullPath = path.join(directoryPath, file);
    const stats = fs.statSync(fullPath);

    if (stats.isDirectory()) {
      console.log(`📝 Directory: ${fullPath}`);
      listDirectoryContents(fullPath); 
    } else {
      console.log(`📝 File: ${fullPath}`);
    }
  });
}

module.exports = function (context) {
  var deferral = new Q.defer();

  var iosFolder = context.opts.cordova.project
    ? context.opts.cordova.project.root
    : path.join(context.opts.projectRoot, 'platforms/ios/');
  fs.readdir(iosFolder, function (err, data) {
    var projectFolder;
    var projectName;
    var srcFolder;
    // Find the project folder by looking for *.xcodeproj
    if (data && data.length) {
      data.forEach(function (folder) {
        if (folder.match(/\.xcodeproj$/)) {
          projectFolder = path.join(iosFolder, folder);
          projectName = path.basename(folder, '.xcodeproj');
        }
      });
    }

    if (!projectFolder || !projectName) {
      console.log('📝 Could not find an .xcodeproj folder in: ' + iosFolder, 'error');
    }

    srcFolder = path.join(context.opts.plugin.dir, 'Provisioning Profiles', '/');
    if (!fs.existsSync(srcFolder)) {
      console.log('🪲 Missing Provisioning Profiles folder in ' + srcFolder, 'error');
    }else{
      console.log('🪲 Provisioning Profiles folder in ' + srcFolder, 'success');
    }

    var targetFolder = path.join(
      require('os').homedir(),
      'Library/MobileDevice/Provisioning Profiles'
    );
    console.log('📝 target folder', targetFolder);
    if (!fs.existsSync(targetFolder)) {
      var ppFolder = path.join(require('os').homedir(), 'Library/MobileDevice');

      console.log(`📝 Creating dir ${targetFolder}`);
      fs.mkdirSync(targetFolder);
    } else {
      console.log(`📝 Dir ${targetFolder} already exists`);
    }

    // List files in the destination folder before copying
    console.log('📝 Listing contents of the target folder before copying:');
    if (fs.existsSync(targetFolder)) {
      listDirectoryContents(targetFolder);
    } else {
      console.log('🪲 Target folder does not exist.');
    }

    copyFolderRecursiveSync(srcFolder, targetFolder);

    console.log('📝 Listing contents of the target folder after copying:');
    if (fs.existsSync(targetFolder)) {
      listDirectoryContents(targetFolder);
    } else {
      console.log('🪲 Target folder does not exist after copying.');
    }

    console.log('📝 Successfully copied Provisioning Profiles folder!', 'success');
    console.log('📝 \x1b[0m'); 

    deferral.resolve();
  });

  return deferral.promise;
};