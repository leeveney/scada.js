require! 'through2': through
require! <[ pug path cheerio fs ]>
require! 'ractive': Ractive
require! 'prelude-ls': {map, keys}
require! '../../templates/filters': {pug-filters}
/*******************************************************************************
USAGE:

Replace `template: '#my-template'` with
    * `template: RACTIVE_PREPARSE('my-template.pug')` if file contains only template code
    * `template: RACTIVE_PREPARSE('my-template.pug', '#some-template-id')` if file contains multiple template codes

Example:

    ractive = new Ractive do
        el: '#main-output'
        template: RACTIVE_PREPARSE('base.pug')

********************************************************************************/

export preparserify-dep-list = {}

preparse-jade = (filename, content, template-id) ->
    """
    Returns {parsed, dependencies}
    """
    dependencies = {}

    ext = path.extname template-file
    dirname = path.dirname filename
    template-full-path = path.join dirname, filename
    template-contents = content

    if ext is \.html
        template-html = template-contents
        dependencies[][template-full-path].push filename
    else if ext is \.pug
        # include templates/mixins.pug file
        mixin-relative = path.relative dirname, process.cwd!
        template-contents = """
            include #{mixin-relative}/templates/mixins.pug
            #{template-contents}
            """

        # TODO: We should get dependencies and rendered content in one function call
        opts = {filename: file, filters: pug-filters, doctype: 'html'}
        compile = pug.compile template-contents, opts
        deps = pug.compileClientWithDependenciesTracked template-contents, opts .dependencies
        # End of TODO

        for dep in (deps ++ template-full-path)
            #console.log "dep is: ", dep, "for the file: ", filename
            dependencies[][dep].push filename

        #console.log "DEPS : ", JSON.stringify preparserify-dep-list, null, 2
        template-html = compile!

    template = if template-id
        $ = cheerio.load template-html, {-lowerCaseAttributeNames, -lowerCaseTags, -decodeEntities}
        try
            $ template-id .html!
        catch
            throw new Error "ractive-preparserify: can not get template id: #{template-id} from #{html}"
    else
        template-html

    # Debug
    #console.log "DEBUG: ractive-preparsify: compiling template: #{path.basename path.dirname file}/#{jade-file} #{template-id or \ALL_HTML }"
    # End of debug

    parsed-template = Ractive.parse template |> JSON.stringify
    
    return {
        parsed: parsed-template
        dependencies: dependencies
    }

function isTemplate file
    return /.*\.(html|pug)$/.test(file);

export ractive-preparserify = (file) ->
    if not isTemplate(file) => return through()

    data = ''
    return through(write, end)

    function write buf 
        data += buf

    function end
        try
            console.log "compiling file: #{file} data: #{data}"
            src = "hello"
            #src = compile(file, data);
        catch error
            this.emit('error', error);

        this.queue(src);
        this.queue(null);

    /*
    through (buf, enc, next) ->
        __ = this
        content = buf.to-string \utf8
        #[template-file, template-id] = params-str.split ',' |> map (.replace /["'\s]+/g, '')
        
        
        # this.push(content.replace /RACTIVE_PREPARSE\(([^\)]+)\)/g, preparse-jade)
        next!
    */
