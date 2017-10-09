let project = new Project('New Project');
project.addAssets('Assets/**');
project.addSources('Test');
project.addLibrary('TextBox');
project.addDefine('test');
resolve(project);
