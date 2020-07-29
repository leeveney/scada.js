require! 'through2': through
require! <[ pug path cheerio fs ]>
require! 'ractive': Ractive
require! 'prelude-ls': {map, keys}
require! '../../templates/filters': {pug-filters}
/*******************************************************************************
USAGE:

Replace `template: '#my-template'` with
    * `template: require('my-template.pug')` if file contains only template code
    * `template: require('my-template.pug', '#some-template-id')` if file contains multiple template codes

Example:

    ractive = new Ractive do
        el: '#main-output'
        template: require('base.pug')

********************************************************************************/

export preparserify-dep-list = {}

preparse-pug = (filename, template) ->
    """
    Returns {parsed, dependencies}
    """
    ext = path.extname filename 
    dirname = path.dirname filename
    template-full-path = path.join dirname, filename

    dependencies = [filename]
    if ext is \.html 
        template-html = template 
    else if ext is \.pug
        # include templates/mixins.pug file
        mixin-relative = path.relative dirname, process.cwd!
        template = """
            include #{mixin-relative}/templates/mixins.pug
            #{template}
            """

        # TODO: We should get dependencies and rendered content in one function call
        opts = {filename: filename, filters: pug-filters, doctype: 'html'}
        compile = pug.compile template, opts
        deps = (pug.compileClientWithDependenciesTracked template, opts).dependencies
        # End of TODO

        dependencies ++= deps 

        #console.log "DEPS : ", JSON.stringify preparserify-dep-list, null, 2
        template-html = compile!

    /* extraction of template from a div is disabled.
    if template-id
        $ = cheerio.load template-html, {-lowerCaseAttributeNames, -lowerCaseTags, -decodeEntities}
        try
            template-html = $ template-id .html!
        catch
            throw new Error "ractive-preparserify: can not get template id: #{template-id} from #{html}"
    */

    # Debug
    #console.log "DEBUG: ractive-preparsify: compiling template: #{path.basename path.dirname file}/#{jade-file} #{template-id or \ALL_HTML }"
    # End of debug

    parsed-template = Ractive.parse template-html
    
    return {
        parsed: parsed-template
        dependencies: dependencies
    }

function isTemplate file
    return /.*\.(html|pug)$/.test(file);

export ractive-preparserify = (file) ->
    if not isTemplate(file)
        return through()
    
    #console.log "ractive-preparserify file is:", file
    contents = ''
    write = (chunk, enc, next) !->
        contents += chunk.to-string \utf-8
        next!

    flush = (cb) -> 
        try
            x = preparse-pug file, contents
            @push "module.exports = #{JSON.stringify x.parsed}"
            /*
            for x.dependencies
                console.log "emitting dependency:", ..
                @emit \file, .. 
            */

            cb!
        catch
            console.error "Preparserify error: ", e
            @emit 'error', e

    return through.obj write, flush

    /*
    this.queue(src);
    this.queue(null);
    */

    /*
    through (buf, enc, next) ->
        __ = this
        content = buf.to-string \utf8
        #[template-file, template-id] = params-str.split ',' |> map (.replace /["'\s]+/g, '')
        
        
        # this.push(content.replace /require\(([^\)]+)\)/g, preparse-jade)
        next!
    */
