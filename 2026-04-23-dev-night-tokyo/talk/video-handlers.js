(function() {
  function attach() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      (function(v) {
        // If the video is wrapped in an <a>, prevent navigation on video clicks
        // (link is only for PDF fallback; in HTML, video controls should work)
        if (v.closest('a')) {
          v.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
          });
        }
        // Double-click to toggle fullscreen (works with or without controls)
        v.addEventListener('dblclick', function(e) {
          e.preventDefault();
          e.stopPropagation();
          if (v.requestFullscreen) {
            v.requestFullscreen().catch(function() {});
          }
        });
      })(videos[i]);
    }
  }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', attach);
  } else {
    attach();
  }
})();
