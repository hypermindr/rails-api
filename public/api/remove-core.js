var HMR = {
	session_id: null,
	debug_mode: true,
	vars: {},
	cookie_name: 'hmRsess',
	cookie_path: '/',
	cookie_domain: false,
	cookie_secure: false,
	api_endpoint: 'http://localhost:3000/v1',
	$: null,
	timer: null,

	setVar: function (name, value)
	{
		this.vars[name] = value;
	},

	getVar: function (name)
	{
		return this.vars[name];
	},

	getSession: function(){
		// check if cookie is set
		var session = this.getCookie(this.cookie_name);

		// if not create
		if(session.length==0){
			session = this.guid();
			this.setCookie(this.cookie_name, session, false, this.cookie_path, this.cookie_domain, this.cookie_secure);
		}

		return session;
	},

	getCookie: function(w){
		var cName = "";
		var pCOOKIES = new Array();
		pCOOKIES = document.cookie.split('; ');
		for(bb = 0; bb < pCOOKIES.length; bb++){
			var NmeVal  = new Array();
			NmeVal  = pCOOKIES[bb].split('=');
			if(NmeVal[0] == w){
				cName = unescape(NmeVal[1]);
			}
		}
		return cName;
	},

	setCookie: function(name, value, expires, path, domain, secure){
		var cookie = name + "=" + escape(value) + "; ";
		if(expires){
			expires = this.setExpiration(expires);
			cookie += "expires=" + expires + "; ";
		}
		if(path) 	cookie += "path=" + path + "; ";
		if(domain) 	cookie += "domain=" + domain + "; ";
		if(secure) 	cookie += "secure; ";
		document.cookie = cookie;
	},

	setExpiration: function(cookieLife){
	    var today = new Date();
	    var expr = new Date(today.getTime() + cookieLife * 24 * 60 * 60 * 1000);
	    return  expr.toGMTString();
	},

	destroyCookie: function(name)
	{
		this.setCookie(name, '', -1, this.cookie_path, this.cookie_domain, this.cookie_secure);
	},

	// generate GUID
	s4: function() {
  		return Math.floor((1 + Math.random()) * 0x10000)
             .toString(16)
             .substring(1);
	},

	guid: function() {
	  return this.s4() + this.s4() + '-' + this.s4() + '-' + this.s4() + '-' +
	         this.s4() + '-' + this.s4() + this.s4() + this.s4();
	},

	debug: function(obj)
	{
		if(this.debug_mode) console.log(obj);
	},

}

HMR.util = {
	is_array : function (input) {
  		return typeof(input)=='object'&&(input instanceof Array);	
  	},	
	strpos : function(haystack, needle, offset) {
	    // Finds position of first occurrence of a string within another  
	    // 
	    // version: 1008.1718
	    // discuss at: http://phpjs.org/functions/strpos
	    // +   original by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +   improved by: Onno Marsman    
	    // +   bugfixed by: Daniel Esteban
	    // +   improved by: Brett Zamir (http://brett-zamir.me)
	    // *     example 1: strpos('Kevin van Zonneveld', 'e', 5);
	    // *     returns 1: 14
	    var i = (haystack+'').indexOf(needle, (offset || 0));
	    return i === -1 ? false : i;
	},

	loadScript: function (url, callback){
		return LazyLoad.js(url, callback);
	},
	
	urlEncode : function(str) {
		// URL-encodes string  
	    // 
	    // version: 1009.2513
	    // discuss at: http://phpjs.org/functions/urlencode
	    // +   original by: Philip Peterson
	    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +      input by: AJ
	    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +   improved by: Brett Zamir (http://brett-zamir.me)
	    // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +      input by: travc
	    // +      input by: Brett Zamir (http://brett-zamir.me)
	    // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +   improved by: Lars Fischer
	    // +      input by: Ratheous
	    // +      reimplemented by: Brett Zamir (http://brett-zamir.me)
	    // +   bugfixed by: Joris
	    // +      reimplemented by: Brett Zamir (http://brett-zamir.me)
	    // %          note 1: This reflects PHP 5.3/6.0+ behavior
	    // %        note 2: Please be aware that this function expects to encode into UTF-8 encoded strings, as found on
	    // %        note 2: pages served as UTF-8
	    // *     example 1: urlencode('Kevin van Zonneveld!');
	    // *     returns 1: 'Kevin+van+Zonneveld%21'
	    // *     example 2: urlencode('http://kevin.vanzonneveld.net/');
	    // *     returns 2: 'http%3A%2F%2Fkevin.vanzonneveld.net%2F'
	    // *     example 3: urlencode('http://www.google.nl/search?q=php.js&ie=utf-8&oe=utf-8&aq=t&rls=com.ubuntu:en-US:unofficial&client=firefox-a');
	    // *     returns 3: 'http%3A%2F%2Fwww.google.nl%2Fsearch%3Fq%3Dphp.js%26ie%3Dutf-8%26oe%3Dutf-8%26aq%3Dt%26rls%3Dcom.ubuntu%3Aen-US%3Aunofficial%26client%3Dfirefox-a'
	    str = (str+'').toString();
	    
	    // Tilde should be allowed unescaped in future versions of PHP (as reflected below), but if you want to reflect current
	    // PHP behavior, you would need to add ".replace(/~/g, '%7E');" to the following.
	    return encodeURIComponent(str).replace(/!/g, '%21').replace(/'/g, '%27').replace(/\(/g, '%28').replace(/\)/g, '%29').replace(/\*/g, '%2A').replace(/%20/g, '+');
	
	},
	
	urldecode : function (str) {
	    // Decodes URL-encoded string  
	    // 
	    // version: 1008.1718
	    // discuss at: http://phpjs.org/functions/urldecode
	    // +   original by: Philip Peterson
	    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +      input by: AJ
	    // +   improved by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +   improved by: Brett Zamir (http://brett-zamir.me)
	    // +      input by: travc
	    // +      input by: Brett Zamir (http://brett-zamir.me)
	    // +   bugfixed by: Kevin van Zonneveld (http://kevin.vanzonneveld.net)
	    // +   improved by: Lars Fischer
	    // +      input by: Ratheous
	    // +   improved by: Orlando
	    // +      reimplemented by: Brett Zamir (http://brett-zamir.me)
	    // +      bugfixed by: Rob
	    // %        note 1: info on what encoding functions to use from: http://xkr.us/articles/javascript/encode-compare/
	    // %        note 2: Please be aware that this function expects to decode from UTF-8 encoded strings, as found on
	    // %        note 2: pages served as UTF-8
	    // *     example 1: urldecode('Kevin+van+Zonneveld%21');
	    // *     returns 1: 'Kevin van Zonneveld!'
	    // *     example 2: urldecode('http%3A%2F%2Fkevin.vanzonneveld.net%2F');
	    // *     returns 2: 'http://kevin.vanzonneveld.net/'
	    // *     example 3: urldecode('http%3A%2F%2Fwww.google.nl%2Fsearch%3Fq%3Dphp.js%26ie%3Dutf-8%26oe%3Dutf-8%26aq%3Dt%26rls%3Dcom.ubuntu%3Aen-US%3Aunofficial%26client%3Dfirefox-a');
	    // *     returns 3: 'http://www.google.nl/search?q=php.js&ie=utf-8&oe=utf-8&aq=t&rls=com.ubuntu:en-US:unofficial&client=firefox-a'
	    
	    return decodeURIComponent(str.replace(/\+/g, '%20'));
	},
  	
  	countObjectProperties : function( obj ) {
  		
    	var size = 0, key;
    	for (key in obj) {
        	if (obj.hasOwnProperty(key)) size++;
    	}
    	return size;
  	},

}

HMR.jQuery = {
	run: function(callback){
		if (window.jQuery)
		{
			HMR.debug('jquery already loaded');
			HMR.$ = window.jQuery;
			callback();
		} else {
			HMR.debug('loading jquery...');
			HMR.util.loadScript('//code.jquery.com/jquery-1.10.2.min.js', function(){
				HMR.debug('done');
				HMR.$ = window.jQuery;
				callback();
			});
		}

	},

}

HMR.commandQueue = function() {

	HMR.debug('Command Queue object created');
	var asyncCmds = [];
}

HMR.commandQueue.prototype = {
	
	push : function (cmd, callback) {
		
		//alert(func[0]);
		var args = Array.prototype.slice.call(cmd, 1);
		//alert(args);
		
		var obj_name = '';
		var method = '';
		var check = HMR.util.strpos( cmd[0], '.' );
		
		if ( ! check ) {
			obj_name = 'HMRTracker';
			method = cmd[0];
		} else {
			var parts = cmd[0].split( '.' );
			obj_name = parts[0];
			method = parts[1];
		}
		
		HMR.debug('cmd queue object name '+ obj_name);
		HMR.debug('cmd queue object method name '+ method);
		
		// is HMRTracker created?
		if ( typeof window[obj_name] == "undefined" ) {
			HMR.debug('making global object named: '+ obj_name);
			window[obj_name] = new HMR.tracker( { globalObjectName: obj_name } );
		}
		
		window[obj_name][method].apply(window[obj_name], args);
		
		if ( callback && ( typeof callback == 'function') ) {
			callback();
		}
	},
	
	loadCmds: function(cmds) {
		
		this.asyncCmds = cmds;
	},
	
	process: function() {
		
		var that = this;
		var callback = function () {
        	// when the handler says it's finished (i.e. runs the callback)
        	// We check for more tasks in the queue and if there are any we run again
        	if (that.asyncCmds.length > 0) {
            	that.process();
         	}
        }
        
        // give the first item in the queue & the callback to the handler
        this.push(this.asyncCmds.shift(), callback);
        
     
		/*
		for (var i=0; i < this.asyncCmds.length;i++) {
			this.push(this.asyncCmds[i]);
		}
		*/
	}
};

HMR.tracker = function(options)
{
	this.options = {};
	if ( options ) {
		
		for (var opt in options) {
			
			this.options[opt] = options[opt];
		}
	}
};

HMR.tracker.prototype = {

	init: function(client_id, apikey){
		HMR.session_id = HMR.getSession();
		HMR.debug(HMR.cookie_name+'='+HMR.session_id);
		HMR.setVar('client_id', client_id);
		HMR.setVar('apikey', apikey);
		var ref = new HMR.uri(document.referrer);
		HMR.setVar('referrer', ref.getHost());
	},

	set_var: function(name, value)
	{
		HMR.setVar(name, value);
	},

	track: function(activity, resource){
		var url = HMR.api_endpoint+'/track_activity';
		//var uri = new HMR.uri( document.URL );
		var send_data = {
					'client_id': HMR.getVar('client_id'),
					'apikey': HMR.getVar('apikey'),
					'user_id': HMR.getVar('hmr_user_id'),
					'external_id': HMR.getVar('external_id'),
					'activity': activity,
					'resource': resource,
					'session_id': HMR.session_id,
					'referrer': HMR.getVar('referrer'),
					};

		HMR.debug(send_data);

		HMR.jQuery.run(function(){
			HMR.$.ajax({
				url: url,
				data: send_data,
				dataType: "jsonp",
				success: function(data, textStatus, jqXHR){
					HMR.debug('success');
					HMR.debug(data);
					},
				});
		});
	},

	log_recommendation: function(product_id, position){
		var url = HMR.api_endpoint+'/track_activity';
		var send_data = {
					'client_id': HMR.getVar('client_id'),
					'apikey': HMR.getVar('apikey'),
					'user_id': HMR.getVar('external_id'),
					'product_id': HMR.getVar('product_id'),
					'position': HMR.getVar('position'),
					};

		HMR.jQuery.run(function(){
			HMR.$.ajax({
				url: url,
				data: send_data,
				dataType: "jsonp",
				type: 'POST',
				success: function(data, textStatus, jqXHR){
					HMR.debug('success');
					HMR.debug(data);
					},
				});
		});
	},

	testApi: function(str)
	{
		var url = HMR.api_endpoint+'/clients';
		HMR.debug(str);

		HMR.jQuery.run(function(){
			HMR.$.ajax({
				url: url,
				dataType: "jsonp",
				complete: function(jqXHR, textStatus){
					HMR.debug('complete');
					HMR.debug({'status': textStatus, 'jqXHR': jqXHR});
					},
				success: function(data, textStatus, jqXHR){
					HMR.debug('success');
					HMR.debug(data);
					},
				});
		});
	},
};

HMR.uri = function( str ) {
	this.components = {};
	this.dirty = false;
	this.options = {
			strictMode: false,
			key: ["source","protocol","authority","userInfo","user","password","host","port","relative","path","directory","file","query","anchor"],
			q:   {
				name:   "queryKey",
				parser: /(?:^|&)([^&=]*)=?([^&]*)/g
			},
			parser: {
				strict: /^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/,
				loose:  /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
			}
	};
	
	if ( str ) {
		this.components = this.parseUri( str );
	}
};

HMR.uri.prototype = {
	
	parseUri : function (str) {
		// parseUri 1.2.2
		// (c) Steven Levithan <stevenlevithan.com>
		// MIT License
		var o = this.options;
		var m   = o.parser[o.strictMode ? "strict" : "loose"].exec(str);
		var uri = {};
		var i   = 14;
	
		while (i--) uri[o.key[i]] = m[i] || "";
	
		uri[o.q.name] = {};
		uri[o.key[12]].replace(o.q.parser, function ($0, $1, $2) {
			if ($1) uri[o.q.name][$1] = $2;
		});
	
		return uri;
	},
	
	getHost : function() {
		
		if (this.components.hasOwnProperty('host')) {
			return this.components.host;
		}
	},
	
	getQueryParam : function ( name ) {
		
		if ( this.components.hasOwnProperty('queryKey')
			&& this.components.queryKey.hasOwnProperty(name) ) {
			return HMR.util.urldecode( this.components.queryKey[name] );
		}
	},
	
	isQueryParam : function( name ) {
	
		if ( this.components.hasOwnProperty('queryKey') 
			&& this.components.queryKey.hasOwnProperty(name) ) {
			return true;
		} else {
			return false;
		}
	},
	
	getComponent : function ( name ) {
	
		if ( this.components.hasOwnProperty( name ) ) {
			return this.components[name];
		}
	},
	
	getProtocol : function() {
		
		return this.getComponent('protocol');
	},
	
	getAnchor : function() {
		
		return this.getComponent('anchor');
	},
	
	getQuery : function() {
		
		return this.getComponent('query');
		
	},
	
	getFile : function() {
		
		return this.getComponent('file');
	},
	
	getRelative : function() {
	
		return this.getComponent('relative');
	},
	
	getDirectory : function() {
		
		return this.getComponent('directory');
	},
	
	getPath : function() {
		
		return this.getComponent('path');
	},
	
	getPort : function() {
	
		return this.getComponent('port');
	},
	
	getPassword : function() {
		
		return this.getComponent('password');
	},
	
	getUser : function() {
		
		return this.getComponent('user');
	},
	
	getUserInfo : function() {
	
		return this.getComponent('userInfo');
	},
	
	getQueryParams : function() {
	
		return this.getComponent('queryKey');
	},
	
	getSource : function() {
	
		return this.getComponent('source');
	},
	
	setQueryParam : function (name, value) {
		
		if ( ! this.components.hasOwnProperty('queryKey') ) {
			
			this.components.queryKey = {};
		}
		
		this.components.queryKey[name] = HMR.util.urlEncode(value);
		
		this.resetQuery();
	},
	
	removeQueryParam : function( name ) {
	
		if ( this.components.hasOwnProperty( 'queryKey' ) 
			 && this.components.queryKey.hasOwnProperty( name )	
		) {
			delete this.components.queryKey[name];			
			this.resetQuery();
		}
	},
	
	resetSource : function() {
	
		this.components.source = this.assembleUrl();
		//alert (this.components.source);
	},
	
	resetQuery : function() {
		
		var qp = this.getQueryParams();
		
		if (qp) {
			
			var query = '';
			var count = HMR.util.countObjectProperties(qp);
			var i = 1;
			
			for (var name in qp) {
				
				query += name + '=' + qp[name];
				
				if (i < count) {
					query += '&';
				}	
			}
			
			this.components.query = query;
			
			this.resetSource();
		}
	},
	
	isDirty : function() {
		
		return this.dirty;
	},
	
	setPath: function ( path ) {
	
	},
	
	assembleUrl : function() {
		
		var url = '';
		
		// protocol
		url += this.getProtocol();
		url += '://';
		// user
		if ( this.getUser() ) {
			url += this.getUser();
		}
		
		// password
		if ( this.getUser() && this.getPassword() ) {
			url += ':' + this.password();
		}
		// host
		url += this.getHost();
		
		// port
		if ( this.getPort() ) {
			url += ':' + this.getPort();
		}

		// directory
		url += this.getDirectory();

		// file
		url += this.getFile();
		
		// query params
		var query = this.getQuery();
		if (query) {
			url += '?' + query;
		}
		
		// query params
		var anchor = this.getAnchor();
		if (anchor) {
			url += '#' + anchor;
		}
		
		
		// anchor
		url += this.getAnchor();
		
		return url;
	}
	
};

/* Start of lazyload */ 
LazyLoad=function(){var f=document,g,b={},e={css:[],js:[]},a;function j(l,k){var m=f.createElement(l),d;for(d in k){if(k.hasOwnProperty(d)){m.setAttribute(d,k[d])}}return m}function h(d){var l=b[d];if(!l){return}var m=l.callback,k=l.urls;k.shift();if(!k.length){if(m){m.call(l.scope||window,l.obj)}b[d]=null;if(e[d].length){i(d)}}}function c(){if(a){return}var k=navigator.userAgent,l=parseFloat,d;a={gecko:0,ie:0,opera:0,webkit:0};d=k.match(/AppleWebKit\/(\S*)/);if(d&&d[1]){a.webkit=l(d[1])}else{d=k.match(/MSIE\s([^;]*)/);if(d&&d[1]){a.ie=l(d[1])}else{if((/Gecko\/(\S*)/).test(k)){a.gecko=1;d=k.match(/rv:([^\s\)]*)/);if(d&&d[1]){a.gecko=l(d[1])}}else{if(d=k.match(/Opera\/(\S*)/)){a.opera=l(d[1])}}}}}function i(r,q,s,m,t){var n,o,l,k,d;c();if(q){q=q.constructor===Array?q:[q];if(r==="css"||a.gecko||a.opera){e[r].push({urls:[].concat(q),callback:s,obj:m,scope:t})}else{for(n=0,o=q.length;n<o;++n){e[r].push({urls:[q[n]],callback:n===o-1?s:null,obj:m,scope:t})}}}if(b[r]||!(k=b[r]=e[r].shift())){return}g=g||f.getElementsByTagName("head")[0];q=k.urls;for(n=0,o=q.length;n<o;++n){d=q[n];if(r==="css"){l=j("link",{href:d,rel:"stylesheet",type:"text/css"})}else{l=j("script",{src:d})}if(a.ie){l.onreadystatechange=function(){var p=this.readyState;if(p==="loaded"||p==="complete"){this.onreadystatechange=null;h(r)}}}else{if(r==="css"&&(a.gecko||a.webkit)){setTimeout(function(){h(r)},50*o)}else{l.onload=l.onerror=function(){h(r)}}}g.appendChild(l)}}return{css:function(l,m,k,d){i("css",l,m,k,d)},js:function(l,m,k,d){i("js",l,m,k,d)}}}();
/* End of lazyload */

(function() {
	
	// execute commands global hmR_cmds command queue
	if ( typeof hmR_cmds === 'undefined' ) {
		var q = new HMR.commandQueue();	
	} else {
		if ( HMR.util.is_array(hmR_cmds) ) {
			var q = new HMR.commandQueue();
			q.loadCmds( hmR_cmds );
		}
	}
	
	window['hmR_cmds'] = q;
	window['hmR_cmds'].process();
	
})();
 

