require! 'yargs':{argv}

if argv.webapp
    webapp = that
else
    console.log "ERROR: You should pass a --webapp=mywebapp parameter. Exiting."
    process.exit!

webapp = argv.webapp
optimize-for-production = yes if argv.production is true


require! <[ watchify gulp browserify glob path fs globby touch ]>
require! 'prelude-ls': {union, join, keys, map, unique, empty}
require! 'vinyl-source-stream': source
require! 'vinyl-buffer': buffer
require! 'gulp-watch': watch
require! 'gulp-pug': pug
require! './templates/filters': {pug-filters}
require! 'buble'
require! 'node-notifier': notifier
require! 'gulp-concat': cat
require! 'gulp-terser': terser
require! './lib/aea': {sleep, pack}
require! './lib/aea/ractive-preparserify': {
    ractive-preparserify
    preparserify-dep-list
}
require! './lib/aea/browserify-optimize-js'
require! 'gulp-flatten': flatten
require! 'gulp-tap': tap
require! 'gulp-cached': cache
require! 'gulp-sourcemaps': sourcemaps
require! 'livescript': lsc
require! 'through2':through
require! 'optimize-js'
require! 'gulp-if-else': if-else
require! 'gulp-rename': rename
require! 'gulp-util': gutil
require! 'gulp-git': git
require! 'gulp-cssimport': cssimport
require! 'event-stream': es

sep = if /^win/.test process.platform => '\\' else '/'

get-version = (path, callback) ->
    if typeof! path is \Function
        callback = path
        path = undefined
    err, stdout <- git.exec {args: 'describe --always --dirty', +quiet, cwd: path}
    [commit, dirtiness] = stdout.split /[-\n]/
    err, stdout <- git.exec {args: 'rev-list --count HEAD', +quiet, cwd: path}
    count = +stdout
    callback {commit, dirty: (dirtiness is \dirty), count}

console.log "------------------------------------------"
#console.log "App\t: #{app}"
console.log "Webapp\t: #{webapp}"

if optimize-for-production
    console.log "------------------------------------------"
    console.log " Gulp will optimize the application for production."
console.log "------------------------------------------"

# Build Settings
notification-enabled = yes

# Project Folder Structure
paths =
    vendor-folder: "#{__dirname}/vendor"
    vendor2-folder: "#{__dirname}/vendor2"
    build-folder: "#{__dirname}/build"
    lib-src: "#{__dirname}/lib"
    client-webapps: "#{__dirname}/../webapps"
    client-root: "#{__dirname}/.."

paths.client-public = "#{paths.build-folder}/#{webapp}"
paths.components-src = "#{__dirname}/components"

notifier.notify {title: "ScadaJS" message: "Webapp \"#{webapp}\" started!"}

on-error = (source, msg) ->
    msg = try
        msg.to-string!
    catch
        "unknown error message: #{msg}" 
    console-msg = "GULP ERROR: #{source} : #{msg}"
    notifier.notify {title: console-msg, message: msg} if notification-enabled
    console.log console-msg

log-info = (source, msg) ->
    msg = try
        msg.to-string!
    catch
        "unknown message: #{e}"
    console-msg = "GULP INFO: #{source} : #{msg}"
    notifier.notify {title: "GULP.#{source}", message: msg} if notification-enabled
    console.log console-msg

pug-entry-files = glob.sync "#{paths.client-webapps}/#{webapp}/index.pug"
html-entry-files = glob.sync "#{paths.client-webapps}/#{webapp}/index.html"
app-entry-files = glob.sync "#{paths.client-webapps}/#{webapp}/app*.{ls,js}"

for-css =
    "#{paths.vendor-folder}/**/*.css"
    "!#{paths.vendor-folder}/**/__tmp__/**"

for-js =
    "#{paths.vendor-folder}/**/*.js"
    "!#{paths.vendor-folder}/**/__tmp__/**"
    "!#{paths.vendor-folder}/**/assets/**"

for-css2 =
    "#{paths.vendor2-folder}/**/*.css"
    "!#{paths.vendor2-folder}/**/__tmp__/**"
    "#{paths.components-src}/**/*.css"
    "#{paths.client-webapps}/**/*.css"

for-js2 =
    "#{paths.vendor2-folder}/**/*.js"
    "!#{paths.vendor2-folder}/**/__tmp__/**"
    "!#{paths.vendor2-folder}/**/assets/**"

# changes on these files will invalidate browserify cache
for-preparserify-workaround =
    "#{paths.client-webapps}/#{webapp}/**/*.pug"
    "#{paths.client-webapps}/#{webapp}/**/*.html"
    "#{paths.components-src}/**/*.pug"
    "#{paths.components-src}/**/*.html"

for-assets =
    "#{paths.components-src}/**/assets/**"
    "#{paths.client-root}/assets/**"
    "#{paths.client-webapps}/**/assets/**"
    "#{__dirname}/assets/**"

    # assets folder in vendor
    "#{paths.vendor-folder}/**/assets/**"
    "!#{paths.vendor-folder}/**/__tmp__/**"
    "!#{paths.vendor-folder}/**/tmp-*/**"

    # assets folder in vendor2
    "#{paths.vendor2-folder}/**/assets/**"
    "!#{paths.vendor2-folder}/**/__tmp__/**"
    "!#{paths.vendor2-folder}/**/tmp-*/**"

for-browserify =
    # livescript files in webapp folder
    "#{paths.client-webapps}/#{webapp}/**/*.ls"
    "#{paths.client-webapps}/#{webapp}/**/*.js"

    # files in components
    "#{paths.components-src}/**/*.ls"
    "#{paths.components-src}/**/*.js"

    # files in lib
    "#{paths.lib-src}/**/*.ls"
    "#{paths.lib-src}/**/*.js"

    # files in project_root/lib
    "#{paths.client-root}/lib/**/*.ls"
    "#{paths.client-root}/lib/**/*.js"

my-uglify = (x) ->
    # mangle: shutterstock/rickshaw/issues/52#issuecomment-313836636
    # keep_fnames: aktos-io/scada.js#172
    terser {-mangle, +keep_fnames} x
    .on \error, gutil.log

my-buble = (input) ->
    t0 = Date.now!
    es5 = buble.transform input, {
          transforms: {
            classes: true
          }
    }
    console.log "*** Transpiled to ES5 in #{((Date.now! - t0)/1000).to-fixed 2}s"
    es5.code

# We need to manually invalidate browserify cache 
# because of preparsing Ractive files requires compiling the Pug files, which 
# in turn requires to track the pug file dependencies. 
browserify-cache = {}

get-bundler = (entry) ->
    b = browserify do
        entries: [entry]
        debug: true
        paths:
            __dirname
            paths.lib-src
            paths.client-webapps
            "#{__dirname}/node_modules"
            "#{__dirname}/.."
        extensions: <[ .ls .pug .html ]>
        cache: browserify-cache
        package-cache: {}
        plugin:
            watchify unless optimize-for-production

    b
        ..transform (file) ->
            # MUST be before ractive-preparserify
            unless /.*\.ls$/.test(file)
                return through!
                
            contents = ''
            write = (chunk, enc, next) !->
                contents += chunk.to-string \utf-8
                next!

            flush = (cb) -> 
                #console.log "lsc file contents:", contents
                try
                    filename = file.replace(/^.*[\\\/]/, '')
                    js = lsc.compile contents, {+bare, -header, map: 'embedded', filename}
                    @push js.code
                    cb!
                catch
                    console.log "Livescript compile error: ", e
                    @emit 'error', e

            return through.obj write, flush 
            
        ..transform ractive-preparserify
        #..transform browserify-optimize-js

# Concatenate vendor javascript files into public/js/vendor.js
compile-js = (watchlist, output) ->
    gulp.src watchlist
        .pipe cat output
        .pipe through.obj (file, enc, cb) ->
            contents = file.contents.to-string!
            optimized = optimize-js contents
            file.contents = new Buffer.from optimized
            cb null, file

        # ES-5 Transpilation MUST BE the last step
        .pipe through.obj (file, enc, cb) ->
            if optimize-for-production
                contents = file.contents.to-string!
                es5 = my-buble contents
                file.contents = new Buffer.from es5
            cb null, file

        # compaction must be after ES-5 transpilation
        .pipe if-else optimize-for-production, my-uglify
        .pipe gulp.dest "#{paths.client-public}/js"

compile-css = (watchlist, output) ->
    gulp.src watchlist
        .pipe cssimport {includePaths: ['node_modules', '../node_modules']}
        .pipe cat output

        # themes are searched in ../themes path, so do not save css in root
        # folder
        .pipe gulp.dest "#{paths.client-public}/css"

# Gulp Tasks 
# ---------------------

# Browserify
# --------------
files = app-entry-files
b-count = files.length
first-browserify-done = no
gulp.task \browserify, ->
    tasks = for let file in files
        filebase = file.split(/[\\/]/).pop! .replace /\.[a-z]+/, '.js'
        console.log "creating bundler task for #{filebase}"
        get-bundler file
            .bundle!
            .on \error, (err) ->
                #console.log "browserify error is:", err 
                msg = err?annotated or err?message or err 
                on-error \browserify, msg
                @emit \end

            .pipe source filebase
            .pipe buffer!

            # ES-5 Transpilation MUST BE the last step
            .pipe through.obj (file, enc, cb) ->
                if optimize-for-production
                    contents = file.contents.to-string!
                    es5 = my-buble contents
                    file.contents = new Buffer.from es5
                cb null, file

            # --- DO NOT CHANGE THE ORDER --- 
            # Although ES-5 Transpilation MUST BE the last step, 
            # if "my-uglify" is executed before ES-5 transpilation, 
            # it takes forever to transpile the uglified output.             
            .pipe if-else optimize-for-production, my-uglify

            .pipe gulp.dest "#{paths.build-folder}/#{webapp}/js"
            .pipe tap (file) ->
                #console.log "browserify cache: ", pack keys browserify-cache
                console.log "Browserify finished (#{webapp}/js/#{filebase})"
                b-count-- if b-count > 0
                if b-count is 0
                    log-info \browserify, "Browserify finished"
                    first-browserify-done := yes
                    b-count := files.length
                    console.log "------------------------------------------"
    return es.merge.apply null, tasks
    
#gulp.task \browserifyAll, gulp.parallel()->
    
gulp.task \versionTrack, ->
    curr = null 
    <~ :lo(op) ~>
        #console.log "checking project version...", version, curr
        version <~ get-version paths.client-root
        if (JSON.stringify(version) isnt JSON.stringify(curr)) 
            curr := JSON.parse JSON.stringify version
            console.log "Changed project version: ", curr 
            """ DEBUG
            dump-file = (name, obj) ->
                require('fs').writeFileSync(name, JSON.stringify(obj, null, 2))

            dump-file "tmp-preparserify-dep-list", preparserify-dep-list
            dump-file "tmp-browserify-cache", browserify-cache
            """
        <~ sleep 1000ms
        lo(op) unless argv.production
# End of Browserify 


gulp.task \html, (done) ->
    # Workaround with if/else:
    # Couldn't make it work like this: https://stackoverflow.com/a/60743545/1952991
    unless empty html-entry-files
        gulp.src html-entry-files, {+allowEmpty}
            #.pipe rename basename: app
            .pipe flatten!
            .pipe gulp.dest paths.client-public        
    done!

gulp.task \vendor-js, ->
    compile-js for-js, "vendor.js"

# Concatenate vendor css files into public/css/vendor.css
gulp.task \vendor-css, ->
    compile-css for-css, "vendor.css"

gulp.task \vendor2-js, ->
    compile-js for-js2, "vendor2.js"

# Concatenate vendor css files into public/css/vendor.css
gulp.task \vendor2-css, ->
    compile-css for-css2, "vendor2.css"

gulp.task \assets, ->
    gulp.src for-assets
        .pipe rename (path) ->
            path-parts = path.dirname.split sep
            parts = []
            found-assets = no
            for i in path-parts
                if i isnt \assets
                    unless found-assets
                        continue
                else
                    if not found-assets
                        found-assets = yes
                        continue
                parts.push i
            _tmp = join sep, parts
            path.dirname = _tmp if found-assets

        # do not send to a subfolder, assets should be in the
        # root folder.
        .pipe gulp.dest paths.client-public


# Compile pug files in paths.client-src to the paths.client-tmp folder
gulp.task \pug (done) ->
    unless empty pug-entry-files
        gulp.src pug-entry-files, {+allowEmpty}
            .pipe tap (file) ->
                #console.log "pug: compiling file: ", path.basename file.path
            .pipe pug do
                pretty: yes
                locals:
                    app: 'ScadaJS'
                filters: pug-filters
            .on \error, (err) ->
                on-error \pug, err
                @emit \end
            #.pipe rename basename: app
            .pipe flatten!
            .pipe gulp.dest paths.client-public
    done!

# FIXME: This is a workaround before ractive-preparserify
# will handle the browserify cache invalidation 
debounce = {}
gulp.task \preparserify-workaround ->
    gulp.src for-preparserify-workaround
        .pipe cache 'preparserify-workaround-cache'
        .pipe tap (file) ->
            #console.log "DEBUG: preparserify-workaround: invalidating: ", file.path
            unless first-browserify-done
                #console.log "DEBUG: Ractive Preparserify: skipping because first browserify is not done yet"
                return
            rel = preparserify-dep-list[file.path]
            rel = [rel] unless typeof! rel is \Array
            rel = unique [.. for rel when ..] # filter out undefined and duplicate files

            unless empty rel
                for js-file in rel
                    #console.log "INFO: Preparserify workaround: triggering for #{path.basename js-file}"
                    try
                        clear-timeout debounce[js-file]
                        console.log "INFO: Preventing debounce for #{js-file}"
                    catch
                        console.log "INFO: ...no need to prevent debounce for #{js-file}"

                    debounce[js-file] = sleep 100ms, ->
                        touch.sync js-file
                        delete debounce[js-file]

gulp.task \watchChanges, (done) ->
    unless optimize-for-production
        watch pug-entry-files, gulp.series \pug 
        watch html-entry-files, gulp.series \html
        watch for-css, gulp.series \vendor-css
        watch for-js, gulp.series \vendor-js
        watch for-css2, gulp.series \vendor2-css
        watch for-js2, gulp.series \vendor2-js
        watch for-assets, gulp.series \assets
        watch for-browserify, gulp.series \browserify
        watch for-preparserify-workaround, gulp.series \preparserify-workaround
    done!

# Start the tasks
gulp.task \default, gulp.series do
    \html
    \vendor-js
    \vendor-css
    \vendor2-js
    \vendor2-css
    \assets
    \pug
    \watchChanges
    \preparserify-workaround
    \versionTrack
    \browserify
