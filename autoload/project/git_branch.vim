let s:name = ''
let s:splitter = ' ||| '

function! project#git_branch#Show()
  let prompt = 'Check out a branch:' 

  call project#PrepareListBuffer(prompt, 'GIT_BRANCH')
  let Init = function('s:Init')
  let Update = function('s:Update')
  let Open = function('s:Open')
  call project#RenderList(Init, Update, Open)
endfunction

function! s:Init(input)
  let format = join(['%(HEAD)', '%(refname:short)', '%(upstream:short)', 
        \'%(contents:subject)', '%(authorname)',  '%(committerdate:relative)'], s:splitter)
  let cmd = "git branch -a --format='".format."'"
  let branches = project#RunShellCmd(cmd)
  let s:list = s:GetTabulatedList(branches)
  call s:Update(a:input)
endfunction

function! s:Update(input)
  let list = s:FilterBranches(s:list, a:input)
  call project#SetVariable('list', list)
  let display = s:GetBranchesDisplay(list, a:input)
  call project#ShowInListBuffer(display, a:input)
  call project#HighlightCurrentLine(len(display))
  call project#HighlightInputChars(a:input)
  call project#HighlightNoResults()
endfunction

function! s:Open(branch, open_cmd, input)
  if a:branch.head == '*'
    return
  endif

  let cmd = 'git checkout '.a:branch.name
  call project#RunShellCmd(cmd)
  call project#Info('Checked out: '.a:branch.name)
endfunction

function! s:FilterBranches(list, input)
  let list = copy(a:list)
  if empty(a:input)
    return list
  endif
  let pattern = s:GetRegexpFilter(a:input)
  let list = filter(list, { idx, val ->
        \s:Match(val.name, pattern)})
  return list
endfunction

function! s:GetRegexpFilter(input)
  return join(split(a:input, ' '), '.*')
endfunction

function! s:Match(string, pattern)
  return match(a:string, a:pattern) != -1
endfunction

function! s:GetTabulatedList(branches)
  let list = []
  for branch in a:branches
    let [head, name, upstream, subject, authorname, date] = split(branch, s:splitter, 1)
    let date = project#ShortenDate(date)
    let show_name = empty(upstream) ? name : name.' -> '.upstream
    call insert(list, {
          \'head': head, 'name': name, 'show_name': show_name, 'date': date,
          \'upstream': upstream, 'subject': subject, 'authorname': authorname,
          \})
  endfor

  call project#Tabulate(list, ['show_name'])
  return list
endfunction

function! s:GetBranchesDisplay(list, input)
  let display = map(copy(a:list), function('s:GetBranchesDisplayRow'))
  return display
endfunction

function! s:GetBranchesDisplayRow(idx, value)
  return a:value.head.' '.a:value.__show_name.' '.a:value.subject.
        \' ('.a:value.authorname.', '.a:value.date.')'
endfunction

