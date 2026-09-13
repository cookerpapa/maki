local th = require("maki.test_helpers")
local helpers = require("tests.helpers")
local case = th.case
local idx = helpers.idx
local idx_with_meta = helpers.idx_with_meta
local has = helpers.has
local indexer = require("indexer")

case("ts_all_sections", function()
  local src = [==[/** Function docs */
import { Request, Response } from 'express';

export interface Config {
    port: number;
    host: string;
}

export type ID = string | number;

export enum Direction { Up, Down }

export const PORT: number = 3000;

export class Service {
    process(input: string): string { return input; }
}

/** Handler doc */
export function handler(req: Request): Response { return new Response(); }
]==]
  local out = idx(src, "typescript")
  has(out, {
    "imports:",
    "{ Request, Response } from 'express'",
    "types:",
    "export interface Config",
    "port: number",
    "type ID",
    "export enum Direction",
    "consts:",
    "PORT",
    "classes:",
    "export Service",
    "fns:",
    "export handler(req: Request)",
  })
end)

case("ts_class_members_have_ranged_meta", function()
  local src = [==[export class Router {
    private routes: Map<string, Function>;
    add(path: string, handler: Function): void { this.routes.set(path, handler); }
    match(url: string): Function | null { return this.routes.get(url) || null; }
}
]==]
  local text, meta = idx_with_meta(src, "typescript")
  helpers.assert_ranged_meta(text, meta, { "add(", "match(" })
end)

local jsx_cases = {
  { "export const x = <T a={<B c={d} />} />;", "consts:", "export x = <T a={<B c={d} />} />" },
  { "const x = <T a={<B c={d} />} />;", "consts:", "x = <T a={<B c={d} />} />" },
  { "export const x = <T a={<B c={d} e={f} />} />;", "consts:", "export x = <T a={<B c={d} e={f} />} />" },
  { "export const x = <T a={<B><C d={e} /></B>} />;", "consts:", "export x = <T a={<B><C d={e} /></B>} />" },
  { "export function x() { return <T a={<B c={d} />} />; }", "fns:", "export x()" },
  { "export const x = <T a={<B />} c={d} />;", "consts:", "export x = <T a={<B />} c={d} />" },
  { "export const x = <T>{<B c={d} />}</T>;", "consts:", "export x = <T>{<B c={d} />}</T>" },
}

for _, ext in ipairs({ "tsx", "jsx" }) do
  for i, fixture in ipairs(jsx_cases) do
    case(ext .. "_nested_jsx_" .. i, function()
      local src = 'import { Route } from "router";\n' .. fixture[1] .. "\nexport const after = 1;\n"
      local out = idx(src, indexer.EXT_TO_LANG[ext])
      has(out, { "imports:", '{ Route } from "router"', fixture[2], fixture[3] .. " [2]", "export after = 1 [3]" })
    end)
  end
end

case("ts_angle_assertion_and_generic_arrow_keep_typescript_grammar", function()
  local out =
    idx("export const x = <number>value;\nexport const identity = <T>(value: T): T => value;\n", indexer.EXT_TO_LANG.ts)
  has(out, { "export x = <number>value [1]", "export identity = <T>(value: T): T => value [2]" })
end)

case("js_extensions_keep_imports_classes_and_functions", function()
  local src = [[import { value } from "source";
export class Example { count = 0; method(input) { return input; } }
export function run(input) { return input; }
export const answer = 42;
]]
  for _, ext in ipairs({ "js", "mjs", "cjs" }) do
    local out = idx(src, indexer.EXT_TO_LANG[ext])
    has(out, {
      "imports:",
      "export Example",
      "count [2]",
      "method(input)",
      "export run(input) [3]",
      "export answer = 42 [4]",
    })
  end
end)
