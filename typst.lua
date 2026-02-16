local get_visual = function(args, parent)
    if #parent.snippet.env.LS_SELECT_RAW > 0 then
        return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
    else -- If LS_SELECT_RAW is empty, return a blank insert node
        return sn(nil, i(1))
    end
end

local line_begin = require('luasnip.extras.expand_conditions').line_begin
-- NOTE: Not in use local line_end = require("luasnip.extras.expand_conditions").line_end
local cond_obj = require 'luasnip.extras.conditions'

-----------------------
-- PRESET CONDITIONS --
-----------------------
--- The wordTrig flag will only expand the snippet if
--- the proceeding character is NOT %w or `_`.
--- This is quite useful. The only issue is that the characters
--- on which we negate on hard coded. See here for the actual implementation
--- https://github.com/L3MON4D3/LuaSnip/blob/c9b9a22904c97d0eb69ccb9bab76037838326817/lua/luasnip/nodes/snippet.lua#L827
---
---
--- @param pattern string valid lua pattern
local function make_trigger_does_not_follow_char(pattern)
    local condition = function(line_to_cursor, matched_trigger)
        local line_to_trigger_len = #line_to_cursor - #matched_trigger
        if line_to_trigger_len == 0 then
            return true
        end
        return not string.sub(line_to_cursor, line_to_trigger_len, line_to_trigger_len):match(pattern)
    end
    return cond_obj.make_condition(condition)
end

local ls = require 'luasnip'
local trigger_does_not_follow_alpha_num_char = make_trigger_does_not_follow_char '%w'
local trigger_does_not_follow_alpha_char = make_trigger_does_not_follow_char '%a'

--- TODO: Rename to Math mode
local MATH_NODES = {
    math = true,
    formula = true,
}

--- TODO: Rename to Content mode
local TEXT_NODES = {
    text = true,
    content = true,
}

--- TODO: Rename to Code mode
local CODE_NODES = {
    code = true,
}

local in_textzone = cond_obj.make_condition(function(check_parent)
    local node = vim.treesitter.get_node { ignore_injections = false }
    while node do
        if node:type() == 'text' then
            if check_parent then
                -- For \text{}
                local parent = node:parent()
                if parent and MATH_NODES[parent:type()] then
                    return false
                end
            end

            return true
        elseif MATH_NODES[node:type()] then
            return false
        end
        node = node:parent()
    end
    return true
end)

local in_codezone = cond_obj.make_condition(function()
    local node = vim.treesitter.get_node { ignore_injections = false }
    while node do
        if CODE_NODES[node:type()] then
            return true
        elseif TEXT_NODES[node:type()] or MATH_NODES[node:type()] then
            return false
        end
        node = node:parent()
    end
    return false
end)

local in_mathzone = cond_obj.make_condition(function()
    local node = vim.treesitter.get_node { ignore_injections = false }
    while node do
        if MATH_NODES[node:type()] then
            return true
        elseif TEXT_NODES[node:type()] or CODE_NODES[node:type()] then
            return false
        end
        node = node:parent()
    end
    return false
end)

local iv = function(i, ...)
    return d(i, get_visual, ...)
end

-- Generating functions for Matrix/Cases - thanks L3MON4D3!
local generate_matrix = function(args, snip)
    local rows = tonumber(snip.captures[2])
    local cols = tonumber(snip.captures[3])
    local nodes = {}
    local ins_indx = 1
    for j = 1, rows do
        table.insert(nodes, r(ins_indx, tostring(j) .. 'x1', i(1)))
        ins_indx = ins_indx + 1
        for k = 2, cols do
            table.insert(nodes, t ' , ')
            table.insert(nodes, r(ins_indx, tostring(j) .. 'x' .. tostring(k), i(1)))
            ins_indx = ins_indx + 1
        end
        table.insert(nodes, t { ';', '' })
    end
    -- fix last node.
    nodes[#nodes] = t ';'
    return sn(nil, nodes)
end

-- update for cases
local generate_cases = function(args, snip)
    local rows = tonumber(snip.captures[1]) or 2 -- default option 2 for cases
    local cols = 2 -- fix to 2 cols
    local nodes = {}
    local ins_indx = 1
    for j = 1, rows do
        table.insert(nodes, r(ins_indx, tostring(j) .. 'x1', i(1)))
        ins_indx = ins_indx + 1
        for k = 2, cols do
            table.insert(nodes, t ' & ')
            table.insert(nodes, r(ins_indx, tostring(j) .. 'x' .. tostring(k), i(1)))
            ins_indx = ins_indx + 1
        end
        table.insert(nodes, t { ',', '' })
    end
    -- fix last node.
    table.remove(nodes, #nodes)
    return sn(nil, nodes)
end

return {
    -- NOTE: Remove auto snippet in the future,
    s(
        { trig = '#grid', snippetType = 'autosnippet' },
        fmta(
            [[
#subpar.grid(
  columns: <>,
  inset: (top: 2em, left: 2em, right: 2em, bottom: 2em),
  gutter: 20pt,
  <>
  caption: [<>]
)<>
]],
            { i(1, '(1fr, 1fr)'), i(2), iv(3), i(0) }
        ),
        { condition = line_begin }
    ),
    s(
        { trig = '#figure', snippetType = 'autosnippet' },
        fmta(
            [[
#figure(
caption: [<>],
supplement: <>,
<>
)<>
]],
            { i(1), i(2, '[Figure]'), iv(3), i(0) }
        ),
        { condition = line_begin }
    ),
    -- FIXME: This is not working reproduce by adding figure as an arg to a subgrid
    s(
        { trig = 'figure', snippetType = 'autosnippet' },
        fmta(
            [[
figure(
caption: [<>],
supplement: <>,
<>
)<>
]],
            { i(1), i(2, '[Figure]'), iv(3), i(0) }
        ),
        { condition = in_codezone }
    ),
    --- 1. Number combination (Sub and super)
    s( -- CY APPROVED
        {
            trig = '([%w%)%]%}|])__',
            desc = 'Subscript with parenthesis',
            wordTrig = false,
            regTrig = true,
            hidden = true,
            snippetType = 'autosnippet',
        },
        fmta('<>_(<>)', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            d(1, get_visual),
        }),
        { condition = in_mathzone }
    ),
    s( -- CY APPROVED
        {
            trig = '([%w%)%]%}|])_([ijknm])',
            desc = 'Automatic subcript for usual letter indices',
            wordTrig = false,
            regTrig = true,
            hidden = true,
            snippetType = 'autosnippet',
        },
        fmta('<>_(<>)<>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            f(function(_, snip)
                return snip.captures[2]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s( -- CY APPROVED
        {
            trig = '([%a%)%]%}|])(%d+)',
            desc = 'Automatic number index',
            wordTrig = false,
            regTrig = true,
            hidden = true,
            snippetType = 'autosnippet',
        },
        fmta('<>_<> <>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            f(function(_, snip)
                return snip.captures[2]
            end),
            d(1, get_visual),
        }),
        { condition = in_mathzone }
    ),
    -- SUBSCRIPT
    s( -- CY APPROVED
        {
            trig = '([%w%)%]%}|])rp',
            desc = 'Mnonetic superscript ([R]aised [P]ower)',
            wordTrig = false,
            regTrig = true,
            hidden = true,
            snippetType = 'autosnippet',
        },
        fmta('<>^(<>)', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            d(1, get_visual),
        }),
        { condition = in_mathzone }
    ),
    s( -- CY APPROVED
        { trig = '([%w%)%]%}|])sq', desc = '[S][Q]uare', wordTrig = false, regTrig = true, snippetType = 'autosnippet', hidden = true },
        fmta('<>^2 <>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s( -- CY APPROVED
        { trig = '([%w%)%]%}|])cb', desc = '[C]u[B]ed', wordTrig = false, regTrig = true, snippetType = 'autosnippet', hidden = true },
        fmta('<>^2 <>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s( -- CY APPROVED
        {
            trig = '([%w%)%]%}|])^([ijknm])',
            desc = 'Automatic superscript for usual letter indices',
            wordTrig = false,
            regTrig = true,
            snippetType = 'autosnippet',
        },
        fmta('<>^(<>)<>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            f(function(_, snip)
                return snip.captures[2]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    -- INVERSE
    s( -- CY APPROVED
        { trig = '([%w%)%]%}])inv', wordTrig = false, regTrig = true, snippetType = 'autosnippet' },
        fmta([[<>^(-1)<>]], {
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    -- DAGGER
    s( -- CY APPROVED
        { trig = '([%w%)%]%}])dag', wordTrig = false, regTrig = true, snippetType = 'autosnippet' },
        fmta([[<>^(dagger)<>]], {
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    --- 2. Big Symbols
    --- This kinda works with \infty and \int too!
    --- NOTE: This won't expand on newline but I tried a regTrig and that did not work
    --- its probably because trigger_does_not_follow_alpha_char has a bug on newlines
    -- s(
    --   { trig = "in ", wordTrig = false, snippetType = "autosnippet" },
    --   t("\\in "),
    --   { condition = in_mathzone * trigger_does_not_follow_alpha_char }
    -- ),
    s(
        { trig = 'int', wordTrig = false, snippetType = 'autosnippet' },
        --- idk if "integral" would be better instead of the symbol
        fmta('∫_(<>)^(<>)<>', {
            d(1, get_visual),
            i(2),
            i(0),
        }),
        { condition = in_mathzone * trigger_does_not_follow_alpha_char }
    ),
    s(
        { trig = 'sum', wordTrig = false, snippetType = 'autosnippet' },
        fmta('sum_(<>)^(<>)<>', {
            d(1, get_visual),
            i(2),
            i(0),
        }),
        { condition = in_mathzone * trigger_does_not_follow_alpha_char }
    ),
    --- https://github.com/michaelfortunato/luasnip-latex-snippets.nvim/blob/main/lua/luasnip-latex-snippets/math_iA.lua

    --- 3. Alone Symbols
    --- 3.1 Operations
    s({
        trig = '*',
        name = '_turn_asterix_to_dot',
        desc = 'Turns asterixs into for more clean notation',
        hidden = true,
        wordTrig = false,
        snippetType = 'autosnippet',
    }, t '· ', { condition = in_mathzone }),
    s({ trig = 'nab', snippetType = 'autosnippet' }, t 'nabla', { condition = in_mathzone }),
    s(
        { trig = '~~', wordTrig = false, snippetType = 'autosnippet' },
        fmta('tilde<>', {
            i(0),
        }),
        { condition = in_mathzone * trigger_does_not_follow_alpha_char }
    ),
    --- Implemented in template
    -- s({ trig = ' o ', snippetType = 'autosnippet' }, t 'compose', { condition = in_mathzone }), 
    -- s({ trig = 'part', snippettype = 'autosnippet' }, t 'partial', { condition = in_mathzone }),
    --- 3.2 Relations

    --- 4. Surrounding
    s({ trig = '||', snippetType = 'autosnippet' }, fmta('norm(<>)<>', { i(1), i(0) }), { condition = in_mathzone }),
    s({ trig = '| ', snippetType = 'autosnippet' }, t 'bar.v ', { condition = in_mathzone }),
    -- Interesting...
    s(
        { trig = '|([^%s][^|]*)|', regTrig = true, snippetType = 'autosnippet' },
        fmta('abs(<>)<>', { f(function(_, snip)
            return snip.captures[1]
        end), i(0) }),
        { condition = in_mathzone }
    ),
    --- 5. Fractions
    --- 5.1 Derivatives
    s(
        { trig = 'd([xytsruv])d([xytsruv])', regTrig = true, snippetType = 'autosnippet' },
        fmta('(d <>)/(d <>)<>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            f(function(_, snip)
                return snip.captures[2]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s(
        { trig = 'dd([xytsruv])', snippetType = 'autosnippet', regTrig = true },
        fmta('(d <>)/(d <>)<>', {
            d(1, get_visual),
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s(
        { trig = 'p([xytsruv])p([xytsruv])', regTrig = true, snippetType = 'autosnippet' },
        fmta('(partial <>)/(partial <>)<>', {
            f(function(_, snip)
                return snip.captures[1]
            end),
            f(function(_, snip)
                return snip.captures[2]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),
    s(
        { trig = 'pp([xytsruv])', snippetType = 'autosnippet', regTrig = true },
        fmta('(partial <>)/(partial <>)<>', {
            d(1, get_visual),
            f(function(_, snip)
                return snip.captures[1]
            end),
            i(0),
        }),
        { condition = in_mathzone }
    ),

    --- Implemented in template
    -- s(
    --     { trig = 'hat', wordTrig = false, snippetType = 'autosnippet' },
    --     fmta([[accent(<>, "^")]], {
    --         i(0),
    --     }),
    --     { condition = in_mathzone * trigger_does_not_follow_alpha_char }
    -- ),
    --- 6.Math environment
    --- 6.1 Enter math mode
    s(
        { trig = 'MM', wordTrig = false, regTrig = false, snippetType = 'autosnippet' },
        fmta(
            [[
$
  <>
$<>]],
            {
                d(1, get_visual),
                i(0),
            }
        ),
        { condition = line_begin }
    ),
    s(
        { trig = 'MM', wordTrig = false, regTrig = false, snippetType = 'autosnippet' },
        fmta(
            [[

$
  <>
$<>]],
            {
                d(1, get_visual),
                i(0),
            },
            { trim_empty = false }
        ),
        { condition = -line_begin * trigger_does_not_follow_alpha_char }
    ),
    --  TODO: Which is faster?
    --   s(
    --     { trig = "MM", wordTrig = false, regTrig = false, snippetType = "autosnippet" },
    --     fmta(
    --       [[<>
    --   <>
    -- $<>]],
    --       {
    --         d(1, function()
    --           local line = vim.api.nvim_get_current_line()
    --           if line:sub(1, -(2 + 1)):match("^%s*$") then
    --             return sn(nil, t({ "$" })) -- Just start of math
    --           else
    --             return sn(nil, t({ "", "$" })) -- Newline + start of math
    --           end
    --         end, {}),
    --         d(2, get_visual),
    --         i(0),
    --       }
    --     ),
    --     { condition = trigger_does_not_follow_alpha_char }
    --   ),
    --- Enter inline mathmode quickly
    s(
        { trig = 'mm', wordtrig = false, snippetType = 'autosnippet' },
        fmta([[$<>$<>]], {
            d(1, get_visual),
            i(0),
        }),
        { condition = trigger_does_not_follow_alpha_char }
    ),
    --- 6.2 Text in math
    s(
        { trig = 'tt', wordTrig = false, snippetType = 'autosnippet' },
        fmta([["<>"<>]], {
            d(1, get_visual),
            i(0),
        }),
        { condition = trigger_does_not_follow_alpha_char * in_mathzone }
    ),

    --- 6.2.1 Greek letters
    s({ trig = 'ga', wordTrig = false, snippetType = 'autosnippet' }, {
        t 'α',
        --t 'alpha',
    }),
    s({ trig = 'gb', wordTrig = false, desc= 'beta', snippetType = 'autosnippet' }, {
        t 'β',
    }),
    s({ trig = 'gg', wordTrig = false, desc= 'gamma', snippetType = 'autosnippet' }, {
        t 'γ',
    }),
    s({ trig = 'gG', wordTrig = false, desc= 'Gamma', snippetType = 'autosnippet' }, {
        t 'Γ',
    }),
    s({ trig = 'gd', wordTrig = false, desc= 'delta', snippetType = 'autosnippet' }, {
        t 'δ',
    }),
    s({ trig = 'gD', wordTrig = false, desc= 'Delta', snippetType = 'autosnippet' }, {
        t 'Δ',
    }),
    s({ trig = 'ge', wordTrig = false, desc= 'epsilon', snippetType = 'autosnippet' }, {
        t 'ε',
    }),
    s({ trig = 'gE', wordTrig = false, desc= 'epsilon alt', snippetType = 'autosnippet' }, {
        t 'ϵ',
    }),
    s({ trig = 'gz', wordTrig = false, desc= 'zeta', snippetType = 'autosnippet' }, {
        t 'ζ',
    }),
    s({ trig = 'gt', wordTrig = false, desc= 'theta', snippetType = 'autosnippet' }, {
        t 'θ',
    }),
    s({ trig = 'gT', wordTrig = false, desc= 'Theta', snippetType = 'autosnippet' }, {
        t 'Θ',
    }),
    s({ trig = 'gl', wordTrig = false, desc= 'lambda', snippetType = 'autosnippet' }, {
        t 'λ',
    }),
    s({ trig = 'gL', wordTrig = false, desc= 'Lambda', snippetType = 'autosnippet' }, {
        t 'Λ',
    }),
    s({ trig = 'gm', wordTrig = false, desc= 'mu', snippetType = 'autosnippet' }, {
        t 'μ',
    }),
    s({ trig = 'gn', wordTrig = false, desc= 'nu', snippetType = 'autosnippet' }, {
        t 'ν',
    }),
    s({ trig = 'gx', wordTrig = false, desc= 'xi', snippetType = 'autosnippet' }, {
        t 'ξ',
    }),
    s({ trig = 'gX', wordTrig = false, desc= 'Xi', snippetType = 'autosnippet' }, {
        t 'Ξ',
    }),
    s({ trig = 'gr', wordTrig = false, desc= 'rho', snippetType = 'autosnippet' }, {
        t 'ρ',
    }),
    s({ trig = 'gs', wordTrig = false, desc= 'sigma', snippetType = 'autosnippet' }, {
        t 'σ',
    }),
    s({ trig = 'gf', wordTrig = false, desc= 'phi', snippetType = 'autosnippet' }, {
        t 'φ',
    }),
    s({ trig = 'gF', wordTrig = false, desc= 'Phi', snippetType = 'autosnippet' }, {
        t 'Φ',
    }),
    s({ trig = 'gc', wordTrig = false, desc= 'chi', snippetType = 'autosnippet' }, {
        t 'χ',
    }),
    s({ trig = 'gp', wordTrig = false, desc= 'psi', snippetType = 'autosnippet' }, {
        t 'ψ',
    }),
    s({ trig = 'gP', wordTrig = false, desc= 'Psi', snippetType = 'autosnippet' }, {
        t 'Ψ',
    }),
    s({ trig = 'gw', wordTrig = false, desc= 'gamma', snippetType = 'autosnippet' }, {
        t 'ω',
    }),
    s({ trig = 'gW', wordTrig = false, desc= 'Gamma', snippetType = 'autosnippet' }, {
        t 'Ω',
    }),
    -- Matrices and Cases
    s( --- CY DUBIOUS
        {
            trig = '([bBpvV]?)mat(%d+)x(%d+)',
            name = '[bBpvV]matrix',
            desc = 'matrices',
            regTrig = true,
            snippetType = 'autosnippet',
        },
        fmta(
            [[
mat(delim:<>,
<>
)<>]],
            {
                f(function(_, snip)
                    local prefix = snip.captures[1] or ''
                    if (prefix == 'b') or (prefix == 'B') then
                        return '"["'
                    elseif (prefix == 'p') or prefix == 'v' or prefix == 'V' then
                        return '"("'
                    else
                        return '"["'
                    end
                end),
                d(1, generate_matrix),
                i(0),
            }
        ),
        { condition = in_mathzone }
    ),

    s( -- CY DUBIOUS
        { trig = '(%d?)cases', name = 'cases', desc = 'cases', regTrig = true, snippetType = 'autosnippet' },
        fmta(
            [[
cases(
<>
)<>]],
            { d(1, generate_cases), i(0) }
        ),
        { condition = in_mathzone }
    ),

}
