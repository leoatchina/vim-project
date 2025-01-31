if exists('g:vim_project_loaded') | finish | endif

function! s:Prepare()
  let s:name = 'vim-project'
  let s:list_history = {}
  let s:laststatus_save = &laststatus
  let s:ruler_save = &ruler
  let s:initial_height = 0
  let s:head_file_job = 0
  let s:project = {}
  let s:branch = ''
  let s:branch_default = ''
  let s:reloading_project = 0
  let s:loading_on_vim_enter = 0
  let s:start_project = {}
  let s:start_buf = ''
  let s:is_init_adding = 0
  let s:init_input = ''
  let s:user_input = ''
  let s:list_buffer = 'vim_project_list'
  let s:nerdtree_tmp = 'vim_project_nerdtree_tmp'
  let s:is_win_version = has('win32') || has('win64')
  let s:view_index = 0

  let s:note_prefix = '- '
  let s:column_pattern = '\S*\(\s\S\+\)*'
  let s:note_column_pattern = '\(\s\{2,}'.s:note_prefix.s:column_pattern.'\)\?'
  let s:first_column_pattern = '^'.s:column_pattern
  let s:second_column_pattern = '\s\{2,}[^- ]'.s:column_pattern

  let s:project_history = []
  let s:add_file = 'project.add.vim'
  let s:ignore_file = 'project.ignore.vim'
  let s:history_file = 'project.history.txt'
  let s:init_file = 'init.vim'
  let s:quit_file = 'quit.vim'

  let s:default = {
        \'config_home':                   '~/.vim/vim-project-config',
        \'project_base':                  ['~'],
        \'use_session':                   0,
        \'open_root_when_use_session':    0,
        \'check_branch_when_use_session': 0,
        \'project_root':                 './',
        \'auto_load_on_start':            0,
        \'include':                       ['./'],
        \'search_include':                [],
        \'find_in_files_include':         [],
        \'exclude':                       ['.git', 'node_modules', '.DS_Store'],
        \'search_exclude':                [],
        \'find_in_files_exclude':         [],
        \'auto_detect':                   'no',
        \'auto_detect_file':              ['.git', '.svn'],
        \'ask_create_directory':          'no',
        \'project_views':                 [],
        \'file_mappings':                 {},
        \'tasks':                         [],
        \'new_tasks':                     [],
        \'new_tasks_post_cmd':            '',
        \'commit_message':                '',
        \'debug':                         0,
        \}

  let s:local_config_keys = [
        \'include',
        \'search_include',
        \'find_in_files_include',
        \'exclude',
        \'search_exclude',
        \'find_in_files_exclude',
        \'project_root',
        \'file_mappings',
        \'tasks',
        \'use_session',
        \'open_root_when_use_session',
        \'check_branch_when_use_session',
        \'commit_message',
        \]

  let s:default.list_mappings = {
        \'open':                 "\<cr>",
        \'close_list':           "\<esc>",
        \'clear_char':           ["\<bs>", "\<c-a>"],
        \'clear_word':           "\<c-w>",
        \'clear_all':            "\<c-u>",
        \'prev_item':            ["\<c-k>", "\<up>"],
        \'next_item':            ["\<c-j>", "\<down>"],
        \'first_item':           ["\<c-h>", "\<left>"],
        \'last_item':            ["\<c-l>", "\<right>"],
        \'scroll_up':            "\<c-p>",
        \'scroll_down':          "\<c-n>",
        \'paste':                "\<c-b>",
        \'switch_to_list':       "\<c-o>",
        \}
  let s:default.list_mappings_projects = {
        \'prev_view':            "\<s-tab>",
        \'next_view':            "\<tab>",
        \}
  let s:default.list_mappings_search_files = {
        \'open_split':           "\<c-s>",
        \'open_vsplit':          "\<c-v>",
        \'open_tabedit':         "\<c-t>",
        \}
  let s:default.list_mappings_find_in_files = {
        \'open_split':           "\<c-s>",
        \'open_vsplit':          "\<c-v>",
        \'open_tabedit':         "\<c-t>",
        \'replace_prompt':       "\<c-r>",
        \'replace_dismiss_item': "\<c-d>",
        \'replace_confirm':      "\<c-y>",
        \}
  let s:default.list_mappings_run_tasks = {
        \'run_task':              "\<cr>",
        \'stop_task':             "\<c-q>",
        \'open_task_terminal':    "\<c-o>",
        \}
  let s:default.file_open_types = {
        \'':  'edit',
        \'s': 'split',
        \'v': 'vsplit',
        \'t': 'tabedit',
        \}

  " Used by statusline
  let g:vim_project = {}

  let s:projects = []
  let s:projects_error = []
  let s:projects_ignore = []
endfunction

function! s:GetConfig(name, default)
  let name = 'g:vim_project_'.a:name
  let value = exists(name) ? eval(name) : a:default

  if a:name == 'config'
    let value = s:MergeUserConfigIntoDefault(value, s:default)
  endif

  return value
endfunction

function! s:MergeUserConfigIntoDefault(user, default)
  let user = a:user
  let default = a:default

  let merge_keys = [
        \'file_open_types',
        \'list_mappings',
        \'list_mappings_projects',
        \'list_mappings_search_files'
        \'list_mappings_find_in_files'
        \'list_mappings_run_tasks',
        \]

  for key in merge_keys
    if has_key(user, key)
      let user[key] = s:MergeUserConfigIntoDefault(user[key], default[key])
    endif
  endfor

  for key in keys(default)
    if has_key(user, key)
      let default[key] = user[key]
    endif
  endfor

  return default
endfunction

function! s:InitConfig()
  let s:config = deepcopy(s:GetConfig('config', {}))
  let s:config_home = expand(s:config.config_home)
  let s:open_root_when_use_session = s:config.open_root_when_use_session
  let s:check_branch_when_use_session = s:config.check_branch_when_use_session
  let s:use_session = s:config.use_session
  let s:project_root = s:config.project_root
  let s:project_base = s:RemoveListTrailingSlash(s:config.project_base)
  let s:include = s:config.include
  let s:search_include = s:config.search_include
  let s:find_in_files_include = s:config.find_in_files_include
  let s:exclude = s:config.exclude
  let s:search_exclude = s:config.search_exclude
  let s:find_in_files_exclude = s:config.find_in_files_exclude

  " options: 'always', 'ask', 'no'
  let s:auto_detect = s:config.auto_detect

  let s:auto_detect_file = s:config.auto_detect_file
  let s:auto_load_on_start = s:config.auto_load_on_start
  let s:ask_create_directory = s:config.ask_create_directory
  let s:project_views = s:config.project_views
  let s:file_mappings = s:config.file_mappings
  let s:list_mappings = s:config.list_mappings
  let s:list_mappings_projects = s:config.list_mappings_projects
  let s:list_mappings_search_files = s:config.list_mappings_search_files
  let s:list_mappings_find_in_files = s:config.list_mappings_find_in_files
  let s:list_mappings_run_tasks = s:config.list_mappings_run_tasks
  let s:open_types = s:config.file_open_types
  let s:tasks = s:config.tasks
  let s:new_tasks = s:config.new_tasks
  let s:new_tasks_post_cmd = s:config.new_tasks_post_cmd
  let s:commit_message = s:config.commit_message
  let s:debug = s:config.debug
endfunction

function! s:ExtendUniqueItems(list1, list2)
  for item in a:list2
    if count(a:list1, item) == 0
      call add(a:list1, item)
    endif
  endfor
endfunction

function! s:AdjustConfig()
  call s:ExtendUniqueItems(s:search_include, s:include)
  call s:ExtendUniqueItems(s:find_in_files_include, s:include)
  call s:ExtendUniqueItems(s:search_exclude, s:exclude)
  call s:ExtendUniqueItems(s:find_in_files_exclude, s:exclude)

  let s:search_include = s:AdjustIncludeExcludePath(s:search_include, ['.'])
  let s:find_in_files_include =
        \s:AdjustIncludeExcludePath(s:find_in_files_include, ['.'])

  let s:search_exclude = s:AdjustIncludeExcludePath(s:search_exclude, [])
  let s:find_in_files_exclude =
        \s:AdjustIncludeExcludePath(s:find_in_files_exclude, [])
endfunction

function! s:RemoveListTrailingSlash(list)
  call map(a:list, {_, val -> s:RemovePathTrailingSlash(val)})
  return a:list
endfunction

function! s:RemoveListHeadingDotSlash(list)
  call map(a:list, {_, val -> s:RemovePathHeadingDotSlash(val)})
  return a:list
endfunction

function! s:AdjustIncludeExcludePath(paths, default)
  let paths = a:paths
  if empty(paths)
    let paths = a:default
  endif
  call s:RemoveListTrailingSlash(paths)
  call s:RemoveListHeadingDotSlash(paths)
  return paths
endfunction

function! s:GetAddArgs(args)
  let args = split(a:args, ',\s*\ze{')
  let path = args[0]
  let option = len(args) > 1 ? json_decode(args[1]) : {}
  return [path, option]
endfunction

function! project#AddProject(args)
  let [path, option] = s:GetAddArgs(a:args)
  let [error, project] = s:AddProject(path, option)
  if error || s:is_init_adding
    return 1
  endif

  let save_path = project#ReplaceHomeWithTide(s:GetFullPath(path))
  if !empty(option)
    call s:SaveToAddFile(save_path.', '.json_encode(option))
  else
    call s:SaveToAddFile(save_path)
  endif
  redraw
  let message = 'Added ['.path.']'
        \.'. Config at ('.project#ReplaceHomeWithTide(s:config_home).')'
  call s:Info(message)
  call project#OpenProject(project)
endfunction

function! s:AddProject(path, ...)
  let fullpath = s:GetFullPath(a:path)
  let option = a:0 > 0 ? a:1 : {}

  let hasProject = project#ProjectExistWithSameFullPath(
        \fullpath,
        \s:projects
        \)
  if hasProject
    if !s:is_init_adding
      call s:Info('Already has ['.a:path.']')
    endif
    return [1, v:null]
  endif

  let name = matchstr(fullpath, '/\zs[^/]*$')
  let path = substitute(fullpath, '/[^/]*$', '', '')
  let note = get(option, 'note', '')
  if !empty(note)
    let note = s:note_prefix.note
  endif

  " fullpath: with project name
  " path: without project name
  let project = {
        \'name': name,
        \'path': path,
        \'fullpath': fullpath,
        \'note': note,
        \'option': option,
        \}

  if !isdirectory(fullpath)
    let created = 0
    if !s:is_init_adding
      let shortpath = project#ReplaceHomeWithTide(fullpath)
      call project#Warn('Directory not found: '.shortpath)

      if s:ask_create_directory == 'yes' && exists("*mkdir")
        let created = s:CreateDirectoryForNewProject(fullpath, shortpath)
      endif
    endif


    if !created
      call insert(s:projects_error, project)
      return [1, v:null]
    endif
  endif

  call s:InitProjectConfig(project)
  call add(s:projects, project)
  return [0, project]
endfunction

function! s:CreateDirectoryForNewProject(fullpath, shortpath)
  echo '[vim-project] Do you want to create directory '.a:shortpath.'? (y/n) '
  if nr2char(getchar()) == 'y'
    redraw
    call mkdir(a:fullpath, 'p')
    call project#Info("Directory created: ".a:shortpath)
    return 1
  endif
  return 0
endfunction

function! project#ProjectExistWithSameFullPath(fullpath, projects)
  let result = 0
  for project in a:projects
    if project.fullpath == a:fullpath
      let result = 1
    endif
  endfor
  return result
endfunction

function! project#IgnoreProject(path)
  let path = project#ReplaceHomeWithTide(a:path)
  let error = s:IgnoreProject(path)
  if !error && !s:is_init_adding
    call s:SaveToPluginConfigIgnore(path)
    redraw
    call s:InfoHl('Ignored '.path)
  endif
endfunction

function! s:ReplaceBackSlash(val)
  if s:is_win_version
    return substitute(a:val, '\', '/', 'g')
  else
    return a:val
  endif
endfunction

function! project#ReplaceHomeWithTide(path)
  let home = escape(expand('~'), '\')
  let home2 = s:ReplaceBackSlash(expand('~'))

  let result = a:path
  let result = substitute(result, '^'.home, '~', '')
  let result = substitute(result, '^'.home2, '~', '')
  return result
endfunction

function! s:RemoveProjectPath(path)
  let result = substitute(a:path, $vim_project, '', '')
  if result != a:path
    let result = substitute(result, '^/', '', '')
  endif
  return result
endfunction

" Ignore path for auto adding
function! s:IgnoreProject(path)
  let fullpath = s:GetFullPath(a:path)
  let hasProject = project#ProjectExistWithSameFullPath(
        \fullpath,
        \s:projects
        \)
  if hasProject
    return -1
  endif

  let name = matchstr(fullpath, '/\zs[^/]*$')
  let path = substitute(fullpath, '/[^/]*$', '', '')
  " path: with project name
  " fullpath: no project name
  let project = {
        \'name': name,
        \'path': path,
        \'fullpath': fullpath,
        \}
  call add(s:projects_ignore, project)
endfunction

function! s:RemovePathTrailingSlash(path)
  return substitute(a:path, '[\/\\]$', '', '')
endfunction

function! s:RemovePathHeadingDotSlash(path)
  return substitute(a:path, '^\.[\/]', '', '')
endfunction

function! s:GetFullPath(path)
  let path = a:path
  let path = s:RemovePathTrailingSlash(path)
  let path = s:GetAbsolutePath(path)
  let path = substitute(expand(path), '\', '\/', 'g')
  call s:Debug('The full path is '.path)
  return path
endfunction

function! s:IsRelativePath(path)
  let path = a:path
  let first = path[0]
  let second = path[1]
  return first != '/' && first != '~' && second != ':'
endfunction

function! s:GetAbsolutePath(path)
  let path = a:path
  if s:IsRelativePath(path)
    let base_list = s:GetProjectBase()
    for base in base_list
      let full_path = s:RemovePathTrailingSlash(expand(fnamemodify(base.'/'.path, ':p')))
      if isdirectory(full_path)
        return full_path
      endif
    endfor
  endif

  if s:IsRelativePath(path)
    let full_path = s:RemovePathTrailingSlash(expand(fnamemodify(getcwd().'/'.path, ':p')))
    return full_path
  endif
  return path
endfunction

function! s:GetProjectBase()
  return insert(copy(s:project_base), getcwd())
endfunction

function! s:InitProjectConfig(project)
  let name = a:project.name
  let config = s:GetProjectConfigPath(s:config_home, a:project)

  if !isdirectory(config) && exists('*mkdir')
    " Create project-specific config files
    call mkdir(config, 'p')

    " Generate init file
    let init_file = config.'/'.s:init_file
    let init_content = [
          \'""""""""""""""""""""""""""""""""""""""""""""""',
          \'" Project:      '.name,
          \'" When:         after session is loaded',
          \'" Variables:    $vim_project, $vim_project_config',
          \'""""""""""""""""""""""""""""""""""""""""""""""',
          \'',
          \'" Local config. Those of list types extend global config. Others override',
          \'" let g:vim_project_local_config = {',
          \'"   \''include'': [''./''],',
          \'"   \''exclude'': [''.git'', ''node_modules'', ''.DS_Store''],',
          \'"   \''tasks'': [',
          \'"     \{',
          \'"       \''name'': ''start'',',
          \'"       \''cmd'': ''npm start''',
          \'"     \},',
          \'"   \],',
          \'"   \''project_root'': ''./'',',
          \'"   \''use_session'': 0,',
          \'"   \''open_root_when_use_session'': 0,',
          \'"   \''check_branch_when_use_session'': 0,',
          \'"   \}',
          \'',
          \'" file_mappings extend global config',
          \'" let g:vim_project_local_config.file_mappings = {',
          \'"   \''r'': ''README.md'',',
          \'"   \''l'': [''html'', ''css'']',
          \'"   \}',
          \'',
          \'let g:vim_project_local_config = {',
          \'\}',
          \'let g:vim_project_local_config.file_mappings = {',
          \'\}',
          \]
    call writefile(init_content, init_file)

    " Generate quit file
    let quit_file = config.'/'.s:quit_file
    let quit_content = [
          \'""""""""""""""""""""""""""""""""""""""""""""""',
          \'" Project name: '.name,
          \'" When:         after session is saved',
          \'" Variables:    $vim_project, $vim_project_config',
          \'""""""""""""""""""""""""""""""""""""""""""""""',
          \]
    call writefile(quit_content, quit_file)
  endif
endfunction

function! s:Debug(msg)
  if s:debug
    echom '['.s:name.'] '.a:msg
  endif
endfunction

function! s:Info(msg, ...)
  echom '['.s:name.'] '.a:msg
endfunction

function! project#Info(msg, ...)
  echom '['.s:name.'] '.a:msg
endfunction

function! project#InfoEcho(msg)
  echo '['.s:name.'] '.a:msg
endfunction

function! s:InfoHl(msg)
  echohl Type | echom '['.s:name.'] '.a:msg | echohl None
endfunction

function! project#Warn(msg)
  redraw
  echohl WarningMsg
  echom '['.s:name.'] '.a:msg
  echohl None
endfunction

function! s:DebugWarn(msg)
  if s:debug
    call project#Warn(a:msg)
  endif
endfunction

function! s:GetProjectConfigPath(config_home, project)
  let id = a:project.path
  let id = project#ReplaceHomeWithTide(id)
  let id = substitute(id, '[/:]', '_', 'g')
  let project_folder = a:project.name.'___@'.id
  return a:config_home.'/'.project_folder
endfunction

function! project#ListProjectNames(A, L, P)
  let projects = deepcopy(s:projects)
  let names =  map(projects, {_, project -> project.name})
  let matches = filter(names, {idx, val -> val =~ a:A})
  return matches
endfunction

function! project#ListAllProjectNames(A, L, P)
  let projects = deepcopy(s:projects + s:projects_error)
  let names =  map(projects, {_, project -> project.name})
  let matches = filter(names, {idx, val -> val =~ a:A})
  return matches
endfunction

function! project#ListDirs(path, L, P)
  let head = s:GetPathHead(a:path)
  let tail = s:GetPathTail(a:path)
  if s:IsRelativePath(a:path)
    let base_list = s:GetProjectBase()
    let head = join(map(base_list, {_, val -> fnamemodify(val.'/'.head, ':p')}), ',')
  endif

  let dirs = split(globpath(head, '*'), "\n")
  call map(dirs,
        \{_, val -> s:ReplaceBackSlash(val)})

  call filter(dirs,
        \{_, val -> match(s:GetPathTail(val), tail) != -1})
  call filter(dirs,
        \{_, val -> isdirectory(expand(val))})
  call map(dirs,
        \{_, val -> project#ReplaceHomeWithTide(val)})

  " If only one found, append a '/' to differentiate it from user input
  if len(dirs) == 1 && isdirectory(expand(dirs[0]))
    let dirs[0] = dirs[0].'/'
  endif

  return dirs
endfunction

function! s:GetPathHead(path)
  return matchstr(a:path, '.*/\ze[^/]*$')
endfunction

function! s:GetPathTail(path)
  let tail = matchstr(a:path, '^[^/]*$')
  if empty(tail)
    let tail = matchstr(a:path, '.*/\zs[^/]*$')
  endif
  return tail
endfunction

" Call this entry function first
function! project#begin()
  let g:vim_project_loaded = 1
  call s:Main()
  call s:SourcePluginConfigFiles()
  call s:ReadProjectHistory()
  call s:WatchOnBufEnter()
endfunction

function! project#checkVersion()
  return s:CheckVersion()
endfunction

function! s:CheckVersion()
  if exists('g:vim_project_config')
        \&& type(g:vim_project_config) == type('')
    let message1 = 'Hey, it seems that you just upgraded. Please configure `g:vim_project_config` as a dict'
    let message2 = 'For details, please check README.md or https://github.com/leafOfTree/vim-project'
    echom '[vim-project] '.message1
    echom '[vim-project] '.message2
    return 1
  endif

  return 0
endfunction

function! s:ReadProjectHistory()
  let history_file = s:config_home.'/'.s:history_file
  if filereadable(history_file)
    let s:project_history = readfile(history_file)
  endif
endfunction

function! s:SourcePluginConfigFiles()
  let add_file = s:config_home.'/'.s:add_file
  let ignore_file = s:config_home.'/'.s:ignore_file
  let s:is_init_adding = 1
  if filereadable(add_file)
    execute 'source '.add_file
  endif
  if filereadable(ignore_file)
    execute 'source '.ignore_file
  endif
  let s:is_init_adding = 0
endfunction

function! s:SaveToAddFile(path)
  let cmd = 'Project '.a:path
  let file = s:config_home.'/'.s:add_file
  call writefile([cmd], file, 'a')
endfunction

function! s:RemoveItemInProjectAddConfig(path)
  let file = s:config_home.'/'.s:add_file
  let adds = readfile(file)
  let idx = s:GetItemIndexInProjectAddConfig(adds, a:path)
  if idx < len(adds)
    call remove(adds, idx)
    call writefile(adds, file)
  endif
endfunction

function! s:RenamePathInProjectAddConfig(path, new_fullpath)
  let file = s:config_home.'/'.s:add_file
  let adds = readfile(file)

  let target = project#ReplaceHomeWithTide(a:path)
  let target_pat = '\s'.escape(target, '~\/').'\ze\($\|\/\|,\)'
  let idx = 0
  for line in adds
    if project#Include(line, target_pat)
      let adds[idx] = substitute(line, target_pat, ' '.a:new_fullpath, '')
    endif
    let idx += 1
  endfor
  call writefile(adds, file)
endfunction

function! s:GetItemIndexInProjectAddConfig(adds, path)
  let target = project#ReplaceHomeWithTide(a:path)
  let target_pat = '\s'.escape(target, '~\/').',\?'
  let idx = 0
  for line in a:adds
    if project#Include(line, target_pat)
      break
    endif
    let idx += 1
  endfor

  return idx
endfunction

function! s:SaveToPluginConfigIgnore(path)
  let file = s:config_home.'/'.s:ignore_file
  let cmd = 'ProjectIgnore '.a:path
  call writefile([cmd], file, 'a')
endfunction

function! s:WatchOnBufEnter()
  augroup vim-project-enter
    autocmd! vim-project-enter
    if s:auto_load_on_start
      " The event order is BufEnter then VimEnter
      autocmd BufEnter * ++once call s:SetStartProjectOnBufEnter()
      autocmd VimEnter * ++once call s:AutoloadOnVimEnter()
    endif
    if s:auto_detect != 'no'
      autocmd BufEnter * call s:AutoDetectProject()
    endif
  augroup END
endfunction

function! s:WatchOnInitFileChange()
  augroup vim-project-init-file-change
    autocmd! vim-project-init-file-change
    autocmd BufWritePost $vim_project_config/init.vim call s:OnInitFileChange()
    
  augroup END
endfunction

function! s:UnwatchOnInitFileChange()
  autocmd! vim-project-init-file-change
endfunction

function! s:OnInitFileChange()
  redraw
  call s:Info('Config Reloaded')
  call s:SourceInitFile()
  call project#search_files#reset()
endfunction

function! s:SetStartProjectOnBufEnter()
  if v:vim_did_enter
    return
  endif

  let buf = expand('<amatch>')
  let project = s:GetProjectByPath(s:projects, buf)

  if empty(project)
    return
  endif
  let s:start_buf = buf
  let s:start_project = project
endfunction

function! s:DoBufEventOnVimEnter()
  doautoall BufRead
  doautoall BufEnter
endfunction

function! s:AutoloadOnVimEnter()
  if empty(s:start_project)
    return
  endif

  let s:loading_on_vim_enter = 1
  execute 'ProjectOpen '.s:start_project.name
  let s:loading_on_vim_enter = 0
  call s:DoBufEventOnVimEnter()
endfunction

function! s:AutoDetectProject()
  if &buftype == ''
    let buf = expand('<amatch>')
    let path = s:GetPathContain(buf, s:auto_detect_file)
    if !empty(path)
      let project = s:GetProjectByFullpath(s:projects, path)
      let ignore = s:GetProjectByFullpath(s:projects_ignore, path)

      if empty(project) && empty(ignore)
        let path = project#ReplaceHomeWithTide(path)
        if s:auto_detect == 'always'
          call s:AutoAddProject(path)
        else
          redraw
          echohl Statement | echon '[vim-project] ' | echohl None
          echon 'Would you like to add "'
          echohl String | echon path | echohl None
          echon '"? ['
          echohl Statement | echon "Y" | echohl None
          echon '/'
          echohl Statement | echon "n" | echohl None
          echon ']'

          while 1
            let c = getchar()
            let char = type(c) == v:t_string ? c : nr2char(c)
            if char ==? 'y'
              call s:AutoAddProject(path)
              break
            endif
            if char ==? 'n'
              call s:AutoIgnoreProject(path)
              break
            endif
            if char == "\<esc>"
              redraw
              call s:InfoHl('Project skipped at this time')
              break
            endif
          endwhile
        endif
      endif
    endif
  endif
endfunction

function! s:AutoAddProject(path)
  call s:AddProject(a:path, {})
  call s:SaveToAddFile(a:path)
  redraw
  call s:InfoHl('Added: '.a:path)
endfunction

function! s:AutoIgnoreProject(path)
  call s:IgnoreProject(a:path)
  call s:SaveToPluginConfigIgnore(a:path)
  redraw
  call s:InfoHl('Ignored '.a:path)
endfunction

function! s:GetPathContain(buf, pats)
  let segments = split(a:buf, '/\|\\', 1)
  let depth = len(segments)

  for i in range(0, depth-1)
    let path = join(segments[0:depth-1-i], '/')
    for p in a:pats
      let matches = globpath(path, p, 1, 1)
      if len(matches) > 0
        return path
      endif
    endfor
  endfor
endfunction

function! s:GetProjectByFullpath(projects, fullpath)
  for project in a:projects
    if project.fullpath is a:fullpath
      return project
    endif
  endfor

  return {}
endfunction

function! s:GetProjectByPath(projects, path)
  let projects = copy(a:projects)
  call filter(projects, {_, project -> project#Include(a:path, project.fullpath)})
  if len(projects) == 1
    return projects[0]
  endif
  if len(projects) > 1
    call sort(projects, {i1, i2 -> len(i2.fullpath) - len(i1.fullpath)})
    return projects[0]
  endif

  return {}
endfunction

" offset: 0,1,2,... from bottom to top
" index: 0,1,2,... from top to bottom
function! project#UpdateOffsetByIndex(index)
  if a:index < len(s:list) - 1
    let s:offset = s:GetCurrentOffset(a:index)
  else
    let s:offset = 0
  endif
endfunction


function! project#PrepareListBuffer(prefix, list_type)
  let s:prefix = a:prefix
  let s:list_type = a:list_type
  " Manually trigger some events first
  silent doautocmd BufLeave
  silent doautocmd FocusLost

  " Ignore events to avoid a cursor bug when opening from Fern.vim
  let save_eventignore = &eventignore
  set eventignore=all
  call s:OpenListBuffer()
  call s:SetupListBuffer()
  let &eventignore = save_eventignore
endfunction

function! s:OpenListBuffer()
  let s:max_height = winheight(0) - 10
  let s:max_width = &columns
  let win = s:list_buffer
  let num = bufwinnr(win)
  if num == -1
    execute 'silent botright split '.win
  else
    execute num.'wincmd w'
  endif
endfunction

function! s:CloseListBuffer(cmd)
  call project#run_tasks#StopRunTasksTimer()

  let &g:laststatus = s:laststatus_save
  let &g:ruler = s:ruler_save

  if !s:IsCurrentListBuffer() || a:cmd == 'switch_to_list'
    return
  endif

  quit
  redraw
  wincmd p
endfunction

function! s:WipeoutListBuffer()
  let num = bufnr(s:list_buffer)
  if num != -1
    execute 'silent bwipeout! '.num
  endif
endfunction

function! s:WatchOnVimQuit()
  augroup vim-quit
    autocmd! vim-quit
    autocmd VimLeave * call s:QuitProject()
    autocmd VimLeave * call s:SaveProjectHistory()
  augroup END
endfunction

function! s:SetupListBuffer()
  if !s:IsCurrentListBuffer()
    return
  endif

  setlocal buftype=nofile bufhidden=delete nobuflisted
  setlocal filetype=vimprojectlist
  setlocal nonumber
  setlocal nocursorline
  setlocal nowrap
  set noruler
  set laststatus=0

  if s:IsFindInFilesList()
    let s:first_column_pattern = '^'.s:column_pattern
    highlight link FirstColumn Keyword
    highlight link SecondColumn Normal
  elseif s:IsRunTasksList()
    let s:first_column_pattern = '^'.s:column_pattern
    highlight link FirstColumn Keyword
    highlight link SecondColumn Comment
    highlight link Status Constant
    call project#run_tasks#Highlight()
  elseif s:IsGitLogList()
    let s:first_column_pattern = '^'.s:column_pattern
    highlight link FirstColumn Normal
    highlight link SecondColumn Comment
  elseif s:IsGitBranchList()
    let s:first_column_pattern = '^\( \|\*\) '.s:column_pattern
    highlight link FirstColumn Normal
    highlight link SecondColumn Comment
  else
    let s:first_column_pattern = '^'.s:column_pattern.s:note_column_pattern
    highlight link FirstColumn Normal
    highlight link SecondColumn Comment
  endif

  syntax clear
  execute 'syntax match InfoRow /^\s\{2,}.*/'
  execute 'syntax match SecondColumn /'.s:second_column_pattern.'/'
  execute 'syntax match FirstColumn /'.s:first_column_pattern.'/'

  highlight link ItemSelected CursorLine
  highlight! link SignColumn Noise
  highlight link InputChar Constant

  call s:HighlightWithBgBasedOn('Comment', 0, 0, 'BeforeReplace')
  call s:HighlightWithBgBasedOn('Function', 0, 'bold', 'AfterReplace')

  sign define selected text=> texthl=ItemSelected linehl=ItemSelected
endfunction

function! s:HighlightWithBgBasedOn(base_group, bg_group, attr, new_group)
  let ctermfg = s:GetArgValue(a:base_group, 'fg', 'cterm')
  let ctermbg = s:GetArgValue(a:base_group, 'bg', 'cterm')
  let guifg = s:GetArgValue(a:base_group, 'fg', 'gui')
  let guibg = s:GetArgValue(a:base_group, 'bg', 'gui')

  if !empty(a:base_group)
    let ctermbg_default = s:GetArgValue(a:bg_group, 'bg', 'cterm')
    let guibg_default = s:GetArgValue(a:bg_group, 'bg', 'gui')
    if empty(ctermbg)
      let ctermbg = ctermbg_default
    endif

    if empty(guibg)
      let guibg = guibg_default
    endif
  endif

  let highlight_cmd = 'highlight '.a:new_group

  if !empty(a:attr)
    let highlight_cmd .= ' term='.a:attr.' cterm='.a:attr.' gui='.a:attr
  endif

  if !empty(ctermfg)
    let highlight_cmd .= ' ctermfg='.ctermfg
  endif
  if !empty(ctermbg)
    let highlight_cmd .= ' ctermbg='.ctermbg
  endif

  if !empty(guifg)
    let highlight_cmd .= ' guifg='.guifg
  endif
  if !empty(guibg)
    let highlight_cmd .= ' guibg='.guibg
  endif

  execute highlight_cmd
endfunction

function! s:GetArgValue(name, what, mode)
  return synIDattr(synIDtrans(hlID(a:name)), a:what, a:mode)
endfunction

function! s:IsCurrentListBuffer()
  return expand('%') == s:list_buffer
endfunction

function! project#HighlightCurrentLine(list_length)
  let length = a:list_length
  sign unplace 9
  if length > 0
    if s:offset > 0
      let s:offset = 0
    endif
    if s:offset < 1 - length
      let s:offset = 1 - length
    endif

    let current = length + s:offset

    if length < s:initial_height
      " Add extra empty liens to keep initial height
      let current += s:initial_height - length
    endif
    execute 'sign place 9 line='.current.' name=selected'
  endif

  if length > s:max_height
    normal! G
    execute 'normal! '.string(current).'G'
  endif
endfunction

function! project#ShowInListBuffer(display, input)
  " Avoid clearing other files by mistake
  if !s:IsCurrentListBuffer()
    return
  endif

  call s:AddToListBuffer(a:display, a:input)
  let length = len(a:display)
  call s:AdjustHeight(length, a:input)
  call s:AddEmptyLines(length)
  call s:RemoveExtraBlankLineAtBottom()
endfunction

function! s:RemoveExtraBlankLineAtBottom()
  normal! G"_dd
  normal! gg
  normal! G
endfunction

function! s:AddToListBuffer(display, input)
  normal! gg"_dG
  if len(a:display) > 0
    call append(0, a:display)
  else
    if len(a:input) > 1
      call append(0, '- No results for: '.a:input)
    endif
  endif
endfunction

function! s:AdjustHeight(length, input)
  if (a:length == 0 && a:input == '') || a:length > s:max_height
    let s:initial_height = s:max_height
  elseif a:input == '' && s:initial_height == 0
    let s:initial_height = a:length
  elseif a:length > s:initial_height && a:length < s:max_height
    let s:initial_height = a:length
  endif

  if winheight(0) != s:initial_height
    execute 'resize '.s:initial_height
  endif
endfunction

function! s:AddEmptyLines(current)
  if a:current < s:initial_height
    let counts = s:initial_height - a:current
    call append(0, repeat([''], counts))
  endif
endfunction

function! s:NextView()
  let max = len(s:project_views)
  let s:view_index = s:view_index < max - 1 ? s:view_index + 1 : 0
endfunction

function! s:PreviousView()
  let max = len(s:project_views)
  let s:view_index = s:view_index > 0 ? s:view_index - 1 : max - 1
endfunction

function! s:AddRightPadding(string, length)
  if strdisplaywidth(a:string) > a:length
    return a:string
  endif

  let padding = repeat(' ', a:length - strdisplaywidth(a:string) + 1)
  return a:string.padding
endfunction

function! project#TabulateFixed(list, keys, widths)
  for item in a:list
    let key_idx = 0
    for key in a:keys
      if strdisplaywidth(item[key]) > a:widths[key_idx]
        let item['__'.key] = s:Truncate(item[key], a:widths[key_idx], '.. ')
      else
        let item['__'.key] = s:AddRightPadding(item[key], a:widths[key_idx])
      endif

      let key_idx = key_idx + 1
    endfor
  endfor
endfunction

function! project#Tabulate(list, keys, min_col_width = 0, max_col_width = &columns)
  " Init max width of each column
  let max = {}

  " Get max width of each column
  for item in a:list
    for key in a:keys
      if has_key(item, key)
        let value = project#ReplaceHomeWithTide(item[key])
        let item['__'.key] = value

        if !has_key(max, key) || len(value) > max[key]
          let max[key] = len(value)
        endif
      endif
    endfor
  endfor

  " If necessary, trim value that is too long
  let max_width = 0
  for value in values(max)
    let max_width += value
  endfor
  if max_width > s:max_width
    let max = {}
    for item in a:list
      for key in a:keys
        if has_key(item, key)
          let value = item['__'.key]
          if len(value) > a:max_col_width
            let value = s:Truncate(value, a:max_col_width, '.. ')
            let item['__'.key] = value
          endif
          if !has_key(max, key) || len(value) > max[key]
            let max[key] = len(value)
          endif
        endif
      endfor
    endfor
  endif

  " Add right padding
  for item in a:list
    for key in a:keys
      if has_key(item, key)
        let max_width = max([max[key], a:min_col_width])
        let item['__'.key] = s:AddRightPadding(item['__'.key], max_width)
      endif
    endfor
  endfor
endfunction

function! s:Truncate(value, max_width, placeholder)
  return a:value[0 : a:max_width - len(a:placeholder)].a:placeholder
endfunction

function! s:GetListCommand(char)
  let mappings = {}
  if s:list_type == 'PROJECTS'
    let mappings = s:list_mappings_projects
  elseif s:list_type == 'SEARCH_FILES'
    let mappings = s:list_mappings_search_files
  elseif s:list_type == 'FIND_IN_FILES'
    let mappings = s:list_mappings_find_in_files
  elseif s:list_type == 'RUN_TASKS'
    let mappings = s:list_mappings_run_tasks
  endif
  " the first takes effect
  let list_mappings = [mappings, s:list_mappings]

  for mappings in list_mappings
    for [command, value] in items(mappings)
      if type(value) == v:t_string
        let match = value == a:char
      else
        let match = count(value, a:char) > 0
      endif

      if match
        return command
      endif
    endfor
  endfor
  return ''
endfunction

function! s:HasFile(list, file)
  for item in a:list
    if has_key(item, 'file') && item.file == a:file
      return 1
    endif
  endfor
  return 0
endfunction

function! project#RunShellCmd(cmd)
  let cd_option = s:is_win_version ? '/d' : ''
  let cmd = 'cd '.cd_option.' '.$vim_project.' && '.a:cmd
  try
    let output = systemlist(cmd)
  catch
    call project#Warn('Exception on running '.a:cmd)
    call project#Warn(v:exception)
    return []
  endtry

  if v:shell_error
    if !empty(output)
      call project#Warn(a:cmd)
      for error in output
        call project#Warn(error)
      endfor
      redraw
      execute (len(output) + 1).'messages'
    endif
    return []
  endif

  return output
endfunction

function! project#hasMoreOnList(list)
  return len(a:list) && has_key(a:list[0], 'more') && a:list[0].more
endfunction


function! project#HighlightNoResults()
  call matchadd('Comment', '- No results for:.*')
endfunction

function! project#HasFindInFilesHistory()
  return has_key(s:list_history, 'FIND_IN_FILES')
endfunction

function! s:ShowInputLine(input)
  redraw
  " Fix cursor flashing when in terminal
  echo ''
  let input = substitute(a:input, ' $', ' ', '')
  echo s:prefix.' '.input
endfunction

function! project#RedrawInputLine()
  call s:ShowInputLine(s:user_input)
endfunction

function! project#HighlightExtraInfo()
  1match String /  ...more$/
endfunction

function! project#RedrawEmptyInputLine()
  call s:ShowInputLine('')
endfunction

function! s:ShowInitialInputLine(input, ...)
  call s:ShowInputLine(a:input)
endfunction

function! project#RenderList(Init, Update, Open, Close = v:null)
  let input = s:InitListVariables(a:Init)
  call s:ShowInitialInputLine(input)
  let [cmd, input] = s:HandleInput(input, a:Update, a:Open)
  call s:CloseListBuffer(cmd)

  if s:IsOpenCmd(cmd)
    call s:OpenTarget(cmd, input, a:Open)
  endif
  call s:SaveListState(input)
  call s:ResetListVariables()
  if !s:IsOpenCmd(cmd) && a:Close != v:null
    call a:Close()
  endif
endfunction

function! s:InitListVariables(Init)
  let has_init_input = !empty(s:init_input)
  let has_history = has_key(s:list_history, s:list_type)
  if has_init_input
    let input = s:init_input
    let s:offset = 0
    let s:initial_height = s:max_height
    let s:init_input = ''
  elseif has_history
    let history = s:list_history[s:list_type]
    let input = history.input
    let s:offset = history.offset
    let s:initial_height = history.initial_height
  else
    let input = ''
    let s:offset = 0
  endif

  " Make sure s:input (saved input), s:replace (saved replace)
  " is differrent from input to trigger query
  let s:input = -1
  let s:replace = -1
  let s:list = []

  call a:Init(input)

  " Empty input if no init and it was set from history ?
  if s:IsFindInFilesList()
    if !has_init_input && has_history
      let s:input = -1
      let input = ''
    endif
  endif

  return input
endfunction

function! s:GetUserInputChar()
  let c = getchar()
  let char = type(c) == v:t_string ? c : nr2char(c)
  return char
endfunction

function! s:ClearCharOfInput(input)
  let length = len(a:input)
  let input = length == 1 ? '' : a:input[0:length-2]
  return input
endfunction

function! s:ClearWordOfInput(input)
  if a:input =~ '\w\s*$'
    let input = substitute(a:input, '\w*\s*$', '', '')
  else
    let input = substitute(a:input, '\W*\s*$', '', '')
  endif
  return input
endfunction

function! s:HandleInput(input, Update, Open)
  let input = a:input

  try
    while 1
      let char = s:GetUserInputChar()
      let cmd = s:GetListCommand(char)
      if cmd == 'close_list'
        break
      elseif cmd == 'clear_char'
        let input = s:ClearCharOfInput(input)
      elseif cmd == 'clear_word'
        let input = s:ClearWordOfInput(input)
      elseif cmd == 'clear_all'
        let input = ''
      elseif cmd == 'prev_item'
        call s:MoveToPrevItem()
      elseif cmd == 'next_item'
        call s:MoveToNextItem()
      elseif cmd == 'first_item'
        let s:offset = 1 - len(s:list)
      elseif cmd == 'last_item'
        let s:offset = 0
      elseif cmd == 'next_view'
        call s:NextView()
      elseif cmd == 'prev_view'
        call s:PreviousView()
      elseif cmd == 'scroll_up'
        let s:offset = s:offset - winheight(0)/2
      elseif cmd == 'scroll_down'
        let s:offset = s:offset + winheight(0)/2
      elseif cmd == 'paste'
        let input .= @*
      elseif cmd == 'replace_prompt'
        let input = project#find_in_files#AddFindReplaceSeparator(input)
      elseif cmd == 'replace_dismiss_item'
        call project#find_in_files#DismissFindReplaceItem()
      elseif cmd == 'replace_confirm'
        call project#find_in_files#ConfirmFindReplace(input)
        break
      elseif cmd == 'switch_to_list'
        break
      elseif cmd == 'open_task_terminal'
        break
      elseif cmd == 'run_task'
        let keep_window = s:OpenTarget('@pass', input, a:Open)
        if !keep_window
          break
        endif
      elseif s:IsOpenCmd(cmd)
        break
      elseif cmd == 'stop_task'
        call project#run_tasks#StopTaskHandler(input)
      else
        let input = input.char
      endif

      call a:Update(input)
      let s:user_input = input
      call s:ShowInputLine(input)
      call s:RemoveNeovideAnimation()
    endwhile
  catch /^Vim:Interrupt$/
    call s:Debug('Interrupt')
    let cmd = 'interrupt'
  finally
  endtry
  call s:RecoverNeovideAnimation()

  return [cmd, input]
endfunction

function! s:RemoveNeovideAnimation()
  if !exists("g:neovide") || g:neovide_scroll_animation_length == 0
    return 
  endif

  let s:neovide_scroll_animation_length = g:neovide_scroll_animation_length
  let g:neovide_scroll_animation_length = 0
endfunction

function! s:RecoverNeovideAnimation()
  if !exists("g:neovide") || !exists('s:neovide_scroll_animation_length')
    return 
  endif
  let g:neovide_scroll_animation_length = s:neovide_scroll_animation_length
  unlet s:neovide_scroll_animation_length
endfunction

function! s:MoveToPrevItem()
  if s:IsRunTasksList()
    let current_line = s:GetCurrentLineNumber()
    call cursor(current_line, 1)
    let prev_task_line = search('^\w', 'bnW')
    let s:offset -= current_line - prev_task_line
  else
    let s:offset -= 1
  endif
endfunction

function! s:MoveToNextItem()
  if s:IsRunTasksList()
    let current_line = s:GetCurrentLineNumber()
    call cursor(current_line, 1)
    let next_task_line = search('^\w', 'nW')
    if next_task_line > current_line
      let s:offset += next_task_line - current_line
    endif
  else
    let s:offset += 1
  endif
endfunction

function! s:GetCurrentLineNumber()
  if winheight(0) > len(s:list)
    return winheight(0) - len(s:list) + project#GetCurrentIndex() + 1
  endif

  return project#GetCurrentIndex() + 1
endfunction

function! s:IsOpenCmd(cmd)
  let open_cmds = ['open', 'open_split', 'open_vsplit', 'open_tabedit', 'run_task', 'open_task_terminal']
  return count(open_cmds, a:cmd) > 0
endfunction

function! s:IsFindInFilesList()
  return s:list_type == 'FIND_IN_FILES'
endfunction

function! s:IsSearchFilesList()
  return s:list_type == 'SEARCH_FILES'
endfunction

function! s:IsRunTasksList()
  return s:list_type == 'RUN_TASKS'
endfunction

function! s:IsGitLogList()
  return s:list_type == 'GIT_LOG'
endfunction

function! s:IsGitBranchList()
  return s:list_type == 'GIT_BRANCH'
endfunction

function! s:IsGitFileHistoryList()
  return s:list_type == 'GIT_FILE_HISTORY'
endfunction

function! s:ShouldSaveListState(input)
  return (s:IsFindInFilesList() && !empty(a:input))
        \|| s:IsRunTasksList()
        \|| s:IsGitLogList()
        \|| s:IsGitFileHistoryList()
endfunction

function! s:SaveListState(input)
  if !s:ShouldSaveListState(a:input)
    return
  endif

  let s:list_history[s:list_type] = {
        \'input': a:input,
        \'offset': s:offset,
        \'initial_height': s:initial_height,
        \}
endfunction

function! s:ResetListVariables()
  unlet! s:input
  let s:initial_height = 0
  unlet! s:list
  unlet! s:prefix
  unlet! s:list_type
endfunction

function! project#GetTarget()
  let index = len(s:list) - 1 + s:offset

  if index >= 0 && index < len(s:list)
    let target = s:list[index]
    return target
  endif

  return {}
endfunction

function! project#GetCurrentIndex()
  return len(s:list) - 1 + s:offset
endfunction

function! s:GetCurrentOffset(index)
  return a:index - len(s:list) + 1
endfunction

function! s:OpenTarget(cmd, input, Open)
  let target = project#GetTarget()

  if empty(target)
    call project#Warn('No item selected')
    return
  endif

  return a:Open(target, a:cmd, a:input)
endfunction

function! s:GetProjectByName(name, projects)
  for project in a:projects
    if project.name == a:name
      return project
    endif
  endfor

  return {}
endfunction

function! project#OpenProjectByName(name)
  let project = s:GetProjectByName(a:name, s:projects)
  if !empty(project)
    call project#OpenProject(project)
  else
    call project#Warn('Project not found: ['.a:name.']')
  endif
endfunction

function! s:RemoveProjectByName(name, is_recursive)
  let project = s:GetProjectByName(a:name, s:projects)
  if empty(project)
    let project = s:GetProjectByName(a:name, s:projects_error)
  endif

  if !empty(project)
    call s:RemoveProject(project)
    call s:RemoveProjectByName(a:name, 1)
  elseif !a:is_recursive
    call project#Warn('Project not found: ['.a:name.']')
  endif
endfunction

function! s:RenameProjectByName(name, new_name)
  let project = s:GetProjectByName(a:name, s:projects)
  if empty(project)
    let project = s:GetProjectByName(a:name, s:projects_error)
  endif

  if !empty(project)
    call s:RenameProject(project, a:new_name)

    let s:projects = []
    let s:projects_error = []
    call s:SourcePluginConfigFiles()
  endif
endfunction

function! project#RemoveProjectByName(name)
  call s:RemoveProjectByName(a:name, 0)
endfunction

function! project#RenameProjectByName(names)
  let [name, new_name] = split(a:names, ' ')
  call s:RenameProjectByName(name, new_name)
endfunction

function! project#ReloadProject()
  call s:ReloadProject()
endfunction

function! s:ReloadProject()
  if project#ProjectExist()
    call s:SaveAllBuffers()
    let s:reloading_project = 1

    let project = s:project
    call s:QuitProject()
    call project#OpenProject(project)

    redraw
    call s:Info('Reloaded')
    let s:reloading_project = 0
  endif
endfunction

function! s:SaveAllBuffers()
  wa
endfunction

function! project#OpenProject(project)
  if s:project != a:project
    call s:ClearCurrentProject()
    let s:project = a:project

    call s:PreLoadProject()
    call s:LoadProject()
    call s:PostLoadProject()
    call s:AddProjectHistory(s:project)
    redraw
    call s:Info('Opened ['.a:project.name.']')
  else
    call s:Info('Already opened')
  endif
endfunction

function! s:AddProjectHistory(project)
  let item = a:project.fullpath
  let idx = index(s:project_history, item)
  if idx != -1
    call remove(s:project_history, idx)
  endif

  call insert(s:project_history, item)
endfunction

function! s:SaveProjectHistory()
  let file = s:config_home.'/'.s:history_file
  call writefile(s:project_history, file)
endfunction

function! s:PreLoadProject()
  call s:InitStartBuffer()
  call s:SetEnvVariables()
endfunction

function! s:LoadProject()
  call s:SourceInitFile()
  call s:WatchOnInitFileChange()
  call s:FindBranch()
  call s:LoadSession()
endfunction

function! s:PostLoadProject()
  call s:SetStartBuffer()
  call s:SyncGlobalVariables()
  call s:StartWatchJob()
  call s:WatchOnVimQuit()
endfunction

function! s:ClearCurrentProject()
  if project#ProjectExist()
    call s:QuitProject()
    silent! %bdelete
  endif
endfunction

function! s:RemoveProject(project)
  if a:project == s:project
    call s:QuitProject()
  endif

  let idx = index(s:projects, a:project)
  if idx >= 0
    call remove(s:projects, idx)
  else
    let idx = index(s:projects_error, a:project)
    if idx >= 0
      call remove(s:projects_error, idx)
    endif
  endif

  if idx >= 0
    call s:Info('Removed the record of ['. a:project.name.'] from ('.a:project.path.')')
    call s:SaveToPluginConfigIgnore(a:project.fullpath)
    call s:RemoveItemInProjectAddConfig(a:project.fullpath)
  endif
endfunction

function! s:RenameProject(project, new_name)
  if a:project == s:project
    call s:QuitProject()
  endif

  call s:Info('Renamed '.a:project.name.' to '.a:new_name.' ('.a:project.path.')')
  let new_fullpath = a:project.path.'/'.a:new_name
  call rename(a:project.fullpath, new_fullpath)
  call s:RenamePathInProjectAddConfig(a:project.fullpath, project#ReplaceHomeWithTide(new_fullpath))

  let config_path = s:GetProjectConfigPath(s:config_home, a:project)
  let a:project.name = a:new_name
  let new_config_path = s:GetProjectConfigPath(s:config_home, a:project)
  call rename(config_path, new_config_path)
endfunction

function! s:SetEnvVariables()
  let $vim_project = s:project.fullpath
  let $vim_project_config =
        \s:GetProjectConfigPath(s:config_home, s:project)
endfunction

function! s:UnsetEnvVariables()
  unlet $vim_project
  unlet $vim_project_config
endfunction

function! project#ProjectExist()
  if empty(s:project)
    return 0
  else
    return 1
  endif
endfunction

function! project#OpenProjectRoot()
  if project#ProjectExist()
    let path = s:GetProjectRootPath()
    if !empty(path)
      execute 'edit '.path
    endif
  endif
endfunction

function! project#OpenProjectConfig()
  if project#ProjectExist()
    let config = s:GetProjectConfigPath(s:config_home, s:project)
    execute 'tabedit '.config.'/'.s:init_file
  else
    call project#Warn('Open a project first')
  endif
endfunction

function! project#OpenAllConfig()
  execute 'tabedit '.s:config_home.'/project.add.vim'
endfunction

function! project#QuitProject()
  call s:QuitProject()
endfunction

function! s:QuitProject()
  if project#ProjectExist()
    call s:Info('Quitted ['.s:project.name.']')
    call s:SaveSession()
    call s:SourceQuitFile()
    call s:UnwatchOnInitFileChange()

    let s:list_history = {}
    let s:project = {}
    call s:UnsetEnvVariables()
    call s:SyncGlobalVariables()

    call s:WipeoutListBuffer()
    call project#search_files#reset()
    call project#run_tasks#reset()
  endif
endfunction

function! s:SyncGlobalVariables()
  if !empty(s:project)
    let g:vim_project = {
          \'name': s:project.name,
          \'path': s:project.path,
          \'fullpath': s:project.fullpath,
          \'note': s:project.note,
          \'option': s:project.option,
          \'branch': s:branch,
          \}
  else
    let g:vim_project = {}
  endif
endfunction

function! project#ShowProjectInfo()
  if !empty(s:project)
    call s:Info('Name: '.s:project.name)
    call s:Info('Path: '.project#ReplaceHomeWithTide(s:project.path))
    call s:Info('config_home: '.s:config.config_home)
    call s:Info('project_base: '.join(s:config.project_base, ', '))
    call s:Info('Include: '.string(s:include))
    call s:Info('Search Include: '.string(s:search_include))
    call s:Info('Find in files Include: '.string(s:find_in_files_include))
    call s:Info('Exclude: '.string(s:exclude))
    call s:Info('Search Exclude: '.string(s:search_exclude))
    call s:Info('Find in files Exclude: '.string(s:find_in_files_exclude))
  else
    call project#Warn('Open a project first')
  endif
endfunction

function! project#ShowProjectAllInfo()
  if !empty(s:project)
    call project#ShowProjectInfo()
    call s:Info('------------ Details ------------')
    call s:ShowProjectConfig()
  else
    call project#Warn('Open a project first')
  endif
endfunction

function! s:ShowProjectConfig()
  for key in sort(keys(s:config))
    if has_key(s:, key)
      let value = s:[key]
    else
      let value = s:config[key]
    endif
    call s:Info(key.': '.string(value))
  endfor
endfunction

function! s:SkipStartBuffer()
  if s:reloading_project || s:loading_on_vim_enter
    return 1
  endif

  return 0
endfunction

function! s:InitStartBuffer()
  if s:SkipStartBuffer()
    return
  endif
  call s:OpenNewBufferOnly()
endfunction

function! s:SetStartBuffer()
  if s:SkipStartBuffer()
    return
  endif

  let path = s:GetProjectRootPath()
  if s:ShouldOpenRoot()
    call s:OpenRoot(path)
  else
    call s:ChangeDirectoryToRoot(path)
  endif
endfunction

function! s:ChangeDirectoryToRoot(path)
  execute 'cd '.a:path
endfunction

function! s:DeleteNerdtreeBuf()
  let bufname = expand('%')
  let is_nerdtree_tmp = count(bufname, s:nerdtree_tmp) == 1
  if is_nerdtree_tmp
    silent bdelete
  endif

  call s:Debug('Opened root from buffer '.bufname)
endfunction

function! s:OpenNewBufferOnly()
  if &buftype == 'terminal'
    " Abandon terminal buffer
    enew!
  else
    if &modified
      " Leave it to uers if it's a modified normal buffer
      new
    else
      enew
    endif
  endif
  silent only
endfunction

function! s:EditPathAsFile(path)
    execute 'edit '.a:path
endfunction

function! s:OpenRootPath(path)
  if exists('g:loaded_nerd_tree')
    let edit_cmd = 'NERDTree'
  else
    let edit_cmd = 'edit'
  endif
  execute edit_cmd.' '.a:path

  silent only
  execute 'cd '.a:path
endfunction

function! s:OpenRoot(path)
  call s:DeleteNerdtreeBuf()

  if empty(a:path)
    call s:OpenNewBufferOnly()
    return
  endif

  if !isdirectory(a:path)
    call s:EditPathAsFile(a:path)
    return
  endif

  call s:OpenRootPath(a:path)
endfunction

function! s:ShouldOpenRoot()
  let bufname = expand('%')
  let is_nerdtree_tmp = count(bufname, s:nerdtree_tmp) == 1

  return s:open_root_when_use_session
        \|| &buftype == 'nofile'
        \|| bufname == ''
        \|| is_nerdtree_tmp
endfunction

function! s:GetProjectRootPath()
  let path = s:project.fullpath
  " Remove the relative part './'
  let root = substitute(s:project_root, '^\.\?[/\\]', '', '')
  let path = path.'/'.root
  if isdirectory(path) || filereadable(path)
    return path
  else
    redraw
    call project#Warn('Project path not found: '.path)
    return ''
  endif
endfunction

function! s:SourceInitFile()
  call s:ResetConfig()
  call s:InitConfig()
  call s:SourceFile(s:init_file)
  call s:ReadLocalConfig()
  call s:AdjustConfig()
  call s:MapFile()
endfunction

function! s:ResetConfig()
  let g:vim_project_local_config = {}
endfunction

function! s:ReadLocalConfig()
  let local_config = s:GetConfig('local_config', {})
  if !empty(local_config)
    for key in s:local_config_keys
      if has_key(local_config, key)
        if type(local_config[key]) == v:t_list
          let s:[key] = extend(copy(s:[key]), local_config[key])
        else
          let s:[key] = local_config[key]
        endif
      endif
    endfor
  endif
endfunction

function! s:SourceQuitFile()
  call s:SourceFile(s:quit_file)
endfunction

function! s:SourceFile(file)
  let name = s:project.name.'-'.s:project.path
  let config = s:GetProjectConfigPath(s:config_home, s:project)
  let file = config.'/'.a:file
  if filereadable(file)
    call s:Debug('Source file: '.file)
    execute 'source '.file
  else
    call s:Debug('File not found: '.file)
  endif
endfunction

function! s:FindBranch()
  if !s:check_branch_when_use_session || !s:use_session
    let s:branch = s:branch_default
    return
  endif

  let head_file = s:project.fullpath.'/.git/HEAD'
  if filereadable(head_file)
    let head = join(readfile(head_file), "\n")

    if !v:shell_error
      let s:branch = matchstr(head, 'refs\/heads\/\zs.*')
    else
      call project#Warn('Error on find branch: '.v:shell_error)
      let s:branch = s:branch_default
    endif
    call s:Debug('Find branch: '.s:branch)
  else
    call s:Info('Not a git repository')
    let s:branch = s:branch_default
  endif
endfunction

function! s:GetSessionFolder()
  if project#ProjectExist()
    let config = s:GetProjectConfigPath(s:config_home, s:project)
    return config.'/sessions'
  else
    return ''
  endif
endfunction


function! s:GetSessionFile()
  if project#ProjectExist()
    let config = s:GetProjectConfigPath(s:config_home, s:project)
    return config.'/sessions/'.s:branch.'.vim'
  else
    return ''
  endif
endfunction

function! s:LoadSession()
  if !s:use_session
    return
  endif

  let file = s:GetSessionFile()
  if filereadable(file)
    call s:Debug('Load session file: '.file)
    execute 'source '.file
  else
    call s:Debug('Not session file found: '.file)
  endif
endfunction

function! s:StartWatchJob()
  let should_watch = s:check_branch_when_use_session
        \&& s:use_session
        \&& executable('tail') == 1
        \&& (exists('*job_start') || exists('*jobstart'))

  if should_watch
    let cmd = s:GetWatchCmd()
    if !empty(cmd)
      if exists('*job_start')
        call s:WatchHeadFileVim(cmd)
      elseif exists('*jobstart')
        call s:WatchHeadFileNeoVim(cmd)
      endif
    endif
  endif
endfunction

function! s:GetWatchCmd()
  let head_file = s:project.fullpath.'/.git/HEAD'
  if filereadable(head_file)
    call s:Debug('Watching .git head file: '.head_file)
    let cmd = 'tail -n0 -F '.head_file
    return cmd
  else
    return ''
  endif
endfunction

function! s:WatchHeadFileVim(cmd)
  if type(s:head_file_job) == v:t_job
    call job_stop(s:head_file_job)
  endif
  let s:head_file_job = job_start(a:cmd,
        \ { 'callback': 'VimProjectReloadSession' })
endfunction

function! s:WatchHeadFileNeoVim(cmd)
  if s:head_file_job
    call jobstop(s:head_file_job)
  endif
  let s:head_file_job = jobstart(a:cmd,
        \ { 'on_stdout': 'VimProjectReloadSession' })
endfunction

function! s:SaveSession()
  if !s:use_session
    return
  endif

  if project#ProjectExist()
    call s:BeforeSaveSession()

    let folder = s:GetSessionFolder()
    if !isdirectory(folder) && exists('*mkdir')
      call mkdir(folder, 'p')
    endif

    let file = s:GetSessionFile()
    call s:Debug('Save session to: '.file)
    execute 'mksession! '.file

    call s:AfterSaveSession()
  endif
endfunction

let s:nerdtree_other = 0
let s:nerdtree_current = 0
function! s:HandleNerdtreeBefore()
  let has_nerdtree = exists('g:loaded_nerd_tree')
        \&& g:NERDTree.IsOpen()
  if has_nerdtree
    if &filetype != 'nerdtree'
      call s:Debug('Toggle nerdtree off')
      let s:nerdtree_other = 1
      NERDTreeToggle
    else
      call s:Debug('Clear nerdtree')
      let s:nerdtree_current = 1
      let s:nerdtree_current_file = expand('%')
      setlocal filetype=
      setlocal syntax=
      execute 'file '.s:nerdtree_tmp
    endif
  endif
endfunction

function! s:HandleNerdtreeAfter()
  if s:nerdtree_other
    let s:nerdtree_other = 0
    call s:Debug('Toggle nerdtree')
    NERDTreeToggle
    wincmd p
  endif
  if s:nerdtree_current
    let s:nerdtree_current = 0
    call s:Debug('Recover nerdtree')
    execute 'file '.s:nerdtree_current_file
    silent! setlocal filetype=nerdtree
    setlocal syntax=nerdtree
  endif
endfunction

let s:floaterm = 0
function! s:handleFloatermBefore()
  let has_floaterm = &filetype == 'floaterm'
  if has_floaterm
    let s:floaterm = 1
    FloatermToggle
  endif
endfunction

function! s:handleFloatermAfter()
  if s:floaterm
    let s:floaterm = 0
    FloatermToggle
  endif
endfunction

function! s:BeforeSaveSession()
  call s:HandleNerdtreeBefore()
endfunction

function! s:AfterSaveSession()
  call s:HandleNerdtreeAfter()
endfunction

function! s:BeforeReloadSession()
  call s:handleFloatermBefore()
endfunction

function! s:AfterReloadSession()
  call s:handleFloatermAfter()
endfunction

function! VimProjectReloadSession(channel, msg, ...)
  if type(a:msg) == v:t_list
    let msg = join(a:msg)
  else
    let msg = a:msg
  endif

  call s:Debug('Trigger reload, msg: '.msg)

  if empty(msg)
    return
  endif

  let new_branch = matchstr(msg, 'refs\/heads\/\zs.*')
  if !empty(new_branch) && new_branch != s:branch
    call s:Info('Changed branch to '.new_branch)
    call s:BeforeReloadSession()

    call s:SaveSession()
    silent! %bdelete
    let s:branch = new_branch
    let g:vim_project.branch = s:branch
    call s:LoadSession()
    call s:SetStartBuffer()

    call s:AfterReloadSession()
  endif
endfunction

function! s:MapFile()
  let config = s:file_mappings

  for [key, V] in items(config)
    let value_type = type(V)
    if value_type == v:t_string
      call s:MapDirectFile(key, V)
    endif

    if value_type == v:t_list
      call s:MapLinkedFile(key, V)
    endif

    if value_type == v:t_func
      call s:MapCustomFile(key)
    endif
  endfor
endfunction

function! s:MapDirectFile(key, file)
  for [open_key, open_type] in items(s:open_types)
    execute "nnoremap '".open_key.a:key.' :update<cr>'
          \.':call <SID>OpenFile("'.open_type.'", "'.a:file.'")<cr>'
  endfor
endfunction

function! s:MapLinkedFile(key, files)
  for [open_key, open_type] in items(s:open_types)
    execute "nnoremap '".open_key.a:key
          \.' :update<cr>:call <SID>GotoLinkedFile('
          \.s:ListToString(a:files).', '.'"'.open_type.'")<cr>'
  endfor
endfunction

function! s:ListToString(list)
  return '['.join(map(copy(a:list), {nr, val -> '"'.val.'"'}),',').']'
endfunction

function! s:CallCustomFunc(key)
  let Func = s:file_mappings[a:key]
  let target = Func()
  return target
endfunction

function! s:MapCustomFile(key)
  let sid = expand('<SID>')
  for [open_key, open_type] in items(s:open_types)
    execute "nnoremap '".open_key.a:key
          \.' :update<cr>'
          \.' :call <SID>OpenFile("'.open_type.'", <SID>CallCustomFunc("'.a:key.'"))<cr>'
  endfor
endfunction

function! s:GotoLinkedFile(files, open_type)
  if a:files[0] =~ '^\w*$' " By file extension
    let current_index = index(a:files, expand('%:e'))
    if current_index == -1 
      call project#Warn('File map extension not found: '.expand('%:e').' in '.join(a:files, ', '))
    else
      let target =  expand('%:p:r').'.'.a:files[1 - current_index]
    endif
  else " By file name, default to first one
    let current_file = substitute(expand('%:p'), $vim_project.'/', '', '')
    let current_index = index(a:files, current_file)
    if current_index == -1
      let target = a:files[0]
    else
      let target = a:files[1 - current_index]
    endif
  endif

  if exists('target')
    call s:OpenFile(a:open_type, target)
  endif
endfunction

function! s:OpenFile(open_type, target)
  let open_target = a:target
  if s:IsRelativePath(open_target)
    let open_target = $vim_project.'/'.open_target
  endif
  let expended_open_target = expand(open_target)

  if !filereadable(expended_open_target) && !isdirectory(expended_open_target)
    let display_target = project#ReplaceHomeWithTide(
          \s:RemoveProjectPath(expended_open_target))
    call project#Warn('File or folder not found: '.display_target)
    return
  endif

  execute a:open_type.' '.expended_open_target
endfunction

function! project#Include(string, search_string)
  return match(a:string, a:search_string) != -1
endfunction

function! project#IsShowHistoryList(input)
  return a:input == '' && s:input == -1 && !empty(s:list)
endfunction

function! project#HighlightInputChars(input)
  call clearmatches()
  if empty(a:input)
    return
  endif
  for lnum in range(max([line('$') - 100, 0]), line('$'))
    let pos = s:GetMatchPos(lnum, a:input)
    if len(pos) == 0
      continue
    endif

    " The maximum number of positions in {pos} is 8.
    for i in range(0, len(pos), 8)
      if empty(pos[i:i+7])
        continue
      endif
      call matchaddpos('InputChar', pos[i:i+7])
    endfor
  endfor
endfunction

" Try columns one by one
function! s:GetMatchPos(lnum, input)
  if empty(a:input)
    return []
  endif

  let search = split(a:input, '\zs')
  let pos = []
  " The start position of match
  let start = 0
  let line = getline(a:lnum)

  let first_col_str = matchstr(line, s:first_column_pattern)
  let first_col = split(first_col_str, '\zs')

  " Try first col full match
  let full_match = match(first_col_str, a:input)
  if full_match > 0
    for start in range(full_match + 1, full_match + len(a:input))
      call add(pos, [a:lnum, start])
    endfor
  endif

  " Try first col
  if start == 0
    let icon_offset = len(first_col_str) - len(first_col)
    for char in search
      let start = index(first_col, char, start, 1) + 1
      if start == 0
        let pos = []
        break
      endif

      call add(pos, [a:lnum, start + icon_offset])
    endfor
  endif

  " No match in first col, try second col
  if start == 0
    let first_length = strlen(first_col_str)
    let second_col_str = matchstr(line, s:second_column_pattern)
    let second_col = split(second_col_str, '\zs')
    let second_index = 0
  endif

  " Try second col full match
  if start == 0
    let full_match = match(second_col_str, a:input)
    if full_match > 0
      for start in range(full_match + 1, full_match + len(a:input))
        call add(pos, [a:lnum, start + first_length])
      endfor
    endif
  endif

  " Try second col
  if start == 0
    for char in search
      let start = index(second_col, char, start, 1) + 1
      if start == 0
        break
      endif

      call add(pos, [a:lnum, start + first_length])
      let second_index += 1
    endfor
  endif

  " Try first col following second col
  if start == 0 && second_index > 0
    for char in search[second_index:]
      let start = index(first_col, char, start, 1) + 1

      if start == 0
        break
      endif

      call add(pos, [a:lnum, start])
    endfor
  endif

  return pos
endfunction

function! project#GetProjectDirectory()
  let path = $vim_project.'/'
  if !has('nvim')
    let path = project#ReplaceHomeWithTide(path)
  endif
  return project#SetSlashBasedOnOS(path)
endfunction

function! project#SetSlashBasedOnOS(val)
  if s:is_win_version
    return substitute(a:val, '/', '\', 'g')
  else
    return substitute(a:val, '\', '/', 'g')
  endif
endfunction

function! project#Exist(name)
  return exists('s:'.a:name)
endfunction

function! project#GetVariable(name)
  return s:[a:name]
endfunction

function! project#SetVariable(name, value)
  let s:[a:name] = a:value
endfunction

function! project#ShortenDate(origin)
  let date = substitute(a:origin, ' years\?', 'y', 'g')
  let date = substitute(date, ' months\?', 'm', 'g')
  let date = substitute(date, ' weeks\?', 'w', 'g')
  let date = substitute(date, ' days\?', 'd', 'g')
  let date = substitute(date, ' hours\?', 'h', 'g')
  return date
endfunction

try
  call nerdfont#find('')
  function! project#GetIcon(fullpath)
    let icon = nerdfont#find(a:fullpath, isdirectory(a:fullpath) ? 'close' : 0)
    if empty(icon)
      return ''
    else
      return icon.' '
    endif
  endfunction
catch 
  function! project#GetIcon(fullpath)
    return ''
  endfunction
endtry

try 
  call glyph_palette#clear()
  function! project#HighlightIcon()
    call glyph_palette#apply()
  endfunction
catch
  function! project#HighlightIcon()
  endfunction
endtry

function! s:Main()
  call s:Prepare()
  call s:InitConfig()
  call s:AdjustConfig()
endfunction
