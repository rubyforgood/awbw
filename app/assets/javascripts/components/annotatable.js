$(function() {
  if( $('.js-annotatable').length > 0 ) {
    var bookmark = $('.js-annotatable').data('bookmark')
    var content = $('.js-annotatable').annotator();
    var annotations = $('.js-annotatable').data('annotations')

    // content.annotator('loadAnnotations', annotations);

    content.annotator('addPlugin', 'Store', {
      prefix: '/api/v1/bookmarks/' + bookmark.id,
      urls: {
          // These are the default URLs.
          index: '/index',
          create:  '/annotations',
          update:  '/annotations/:id',
          destroy: '/annotations/:id',
          search:  '/search'
        },

      // Attach the uri of the current page to all annotations to allow search.
      annotationData: {
        'uri': 'http://localhost:3000'
      },

      // This will perform a "search" action when the plugin loads. Will
      // request the last 20 annotations for the current url.
      // eg. /store/endpoint/search?limit=20&uri=http://this/document/only
      // loadFromSearch: {
      //   'limit': 20,
      //   'uri': 'http://localhost:3000'
      // }
    });
  }
})
