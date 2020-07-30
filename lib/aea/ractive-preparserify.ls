require! 'through': through
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

export ractive-preparserify = (cache) -> 
    #console.log "ractive-preparserify file is:", file
    # TODO: https://stackoverflow.com/questions/63151235/how-to-tell-browserify-to-invalidate-the-related-caches-through-a-transform-modu    
    return (file) ->
        if not isTemplate(file)
            return through()        
        console.log "Ractive preparserifying file: #file"
        contents = ''
        write = (chunk) !->
            contents += chunk.to-string \utf-8

        end = -> 
            try
                x = preparse-pug file, contents
                for x.dependencies
                    @emit \dep, ..
                @queue "module.exports = #{JSON.stringify x.parsed}"
            catch
                console.error "Preparserify error: ", e
                @emit 'error', e
            @queue null 

        return through write, end
