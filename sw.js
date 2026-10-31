// PTN Team Tracker service worker: makes the site installable and lets the
// app shell open without a connection. Network-first, so every launch gets
// the latest index.html from GitHub Pages; the cache is only a fallback.
// Supabase, fonts and CDN requests are cross-origin and pass straight through.

var CACHE = "ptn-shell-v1";
var SHELL = ["./", "./index.html", "./manifest.webmanifest", "./icons/apple-touch-icon.png", "./icons/icon-192.png", "./icons/icon-512.png"];

self.addEventListener("install", function(e){
  e.waitUntil(caches.open(CACHE).then(function(c){ return c.addAll(SHELL); }).then(function(){ return self.skipWaiting(); }));
});

self.addEventListener("activate", function(e){
  e.waitUntil(caches.keys().then(function(keys){
    return Promise.all(keys.filter(function(k){ return k!==CACHE; }).map(function(k){ return caches.delete(k); }));
  }).then(function(){ return self.clients.claim(); }));
});

self.addEventListener("fetch", function(e){
  var req = e.request;
  if(req.method!=="GET" || new URL(req.url).origin!==self.location.origin) return;
  e.respondWith(fetch(req).then(function(res){
    if(res.ok){ var copy = res.clone(); caches.open(CACHE).then(function(c){ c.put(req, copy); }); }
    return res;
  }).catch(function(){
    return caches.match(req).then(function(hit){ return hit || caches.match("./index.html"); });
  }));
});
