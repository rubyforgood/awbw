CKEDITOR.editorConfig = function(config) {
  config.assets_languages = ['en']
  config.language = "en";
  config.extraPlugins = 'youtube,imageuploader';
  // config.toolbar = [{name: 'insert', items: ['Youtube']}]
  config.toolbarGroups = [
      { name: 'document', groups: [ 'mode', 'document', 'doctools' ] },
      { name: 'clipboard', groups: [ 'clipboard', 'undo' ] },
      { name: 'editing', groups: [ 'find', 'selection', 'spellchecker', 'editing' ] },
      { name: 'forms', groups: [ 'forms' ] },
      '/',
      { name: 'basicstyles', groups: [ 'basicstyles', 'cleanup' ] },
      { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align', 'bidi', 'paragraph' ] },
      { name: 'links', groups: [ 'links' ] },
      { name: 'insert', groups: [ 'insert' ] },
      '/',
      { name: 'styles', groups: [ 'styles' ] },
      { name: 'colors', groups: [ 'colors' ] },
      { name: 'tools', groups: [ 'tools' ] },
      { name: 'others', groups: [ 'others' ] },
      { name: 'about', groups: [ 'about' ] }
    ];

  config.filebrowserImageBrowseUrl = "/admin/ckeditor/pictures";
  config.filebrowserImageUploadUrl = "/admin/ckeditor/pictures";
  config.uploadUrl = "/admin/ckeditor/pictures";
  config.allowedContent = true;
  config.scayt_autoStartup = true;

  config.removeButtons = 'Underline,Subscript,Superscript';

  // Set the most common block elements.
  config.format_tags = 'p;h1;h2;h3;pre';

  // Simplify the dialog windows.
 config.removeDialogTabs = 'image:advanced;link:advanced';
};

CKEDITOR.on( 'dialogDefinition', function( ev ) {
    var dialogName = ev.data.name;
    var dialogDefinition = ev.data.definition;

    if ( dialogName == 'table' ) {
        var info = dialogDefinition.getContents( 'info' );

        info.get( 'txtBorder' )[ 'default' ] = '0';
        info.get( 'txtCellSpace' )[ 'default' ] = '0';
        info.get( 'txtCellPad' )[ 'default' ] = '0';
    }

    if ( dialogName == 'image' ) {
        var info = dialogDefinition.getContents( 'info' );
        info.get( 'txtHSpace' )[ 'default' ] = '10';
    }
});


CKEDITOR.stylesSet.add( 'custom_styles',
  [
    // Block-level styles
    { name : 'Body', element : 'p', styles : { 'font-family' : 'Arial',' font-size': '14px' } },
      { name : 'Caption', element : 'span', styles : { 'font-family' : 'Arial',' font-size': '12px', 'font-weight': 'Bold', 'font-style': 'italic', 'line-height': '1.3'}, attributes : { 'class': 'awbw-caption' } },
      { name : 'Sub-head', element : 'h3', styles : { 'font-family' : 'Arial',' font-size': '14px', 'font-weight': 'Bold', 'font-style': 'italic', 'line-height': '1.3'}},
      { name : 'Sub-sub', element : 'h4', styles : { 'font-family' : 'Arial',' font-size': '14px', 'font-weight': 'normal', 'font-style': 'italic', 'line-height': '1.3'}},
      { name : 'Steps', element : 'step', styles : { 'font-family' : 'Arial',' font-size': '14px', 'font-weight': 'bold', 'line-height': '1.3'} }
  ]);

CKEDITOR.addCss('body{font-family:Arial;font-size: 14px;}');

// For inline style definition
CKEDITOR.config.stylesSet = 'custom_styles';
