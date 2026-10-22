.pragma library

// A small calculator for the launcher's `=` mode. A recursive-descent
// parser, so nothing typed here is ever evaluated as code.
//   + - * / % ^, parentheses, unary minus, implicit "2pi"
//   sqrt cbrt abs round floor ceil sin cos tan asin acos atan ln log exp
//   constants pi, e, tau

const FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: Math.round,
    floor: Math.floor, ceil: Math.ceil, sin: Math.sin, cos: Math.cos,
    tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
    ln: Math.log, log: Math.log10, exp: Math.exp,
};
const CONSTS = { pi: Math.PI, e: Math.E, tau: Math.PI * 2 };

function tokenize(src) {
    const out = [];
    let i = 0;
    while (i < src.length) {
        const c = src[i];
        if (/\s/.test(c)) { i++; continue; }
        const num = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/i.exec(src.slice(i));
        if (num) { out.push({ t: "n", v: parseFloat(num[0].replace(/_/g, "")) }); i += num[0].length; continue; }
        const id = /^[a-z]+/i.exec(src.slice(i));
        if (id) { out.push({ t: "id", v: id[0].toLowerCase() }); i += id[0].length; continue; }
        const op = c === "×" ? "*" : c === "÷" ? "/" : c === "−" ? "-" : c === "," ? "." : c;
        if ("+-*/%^()".includes(op)) { out.push({ t: op }); i++; continue; }
        throw new Error(`unexpected “${c}”`);
    }
    return out;
}

function parse(tokens) {
    let p = 0;
    const peek = () => tokens[p];
    const eat = t => {
        if (peek()?.t !== t) throw new Error(`expected ${t}`);
        return tokens[p++];
    };

    // expr := term (("+" | "-") term)*
    function expr() {
        let v = term();
        while (peek() && (peek().t === "+" || peek().t === "-"))
            v = tokens[p++].t === "+" ? v + term() : v - term();
        return v;
    }
    // term := unary (("*" | "/" | "%") unary | implicit unary)*
    function term() {
        let v = unary();
        for (;;) {
            const t = peek()?.t;
            if (t === "*") { p++; v *= unary(); }
            else if (t === "/") { p++; v /= unary(); }
            else if (t === "%") { p++; v %= unary(); }
            else if (t === "(" || t === "id" || t === "n") v *= unary();   // 2pi, 3(4+1)
            else return v;
        }
    }
    // unary := "-" unary | power
    function unary() {
        if (peek()?.t === "-") { p++; return -unary(); }
        if (peek()?.t === "+") { p++; return unary(); }
        return power();
    }
    // power := atom ("^" unary)?   (right-associative)
    function power() {
        const base = atom();
        if (peek()?.t === "^") { p++; return Math.pow(base, unary()); }
        return base;
    }
    function atom() {
        const tok = tokens[p++];
        if (!tok) throw new Error("incomplete");
        if (tok.t === "n") return tok.v;
        if (tok.t === "(") { const v = expr(); eat(")"); return v; }
        if (tok.t === "id") {
            if (tok.v in CONSTS) return CONSTS[tok.v];
            if (tok.v in FUNCS) {
                if (peek()?.t === "(") { p++; const v = expr(); eat(")"); return FUNCS[tok.v](v); }
                return FUNCS[tok.v](power());
            }
            throw new Error(`unknown “${tok.v}”`);
        }
        throw new Error(`unexpected “${tok.t}”`);
    }

    const v = expr();
    if (p < tokens.length) throw new Error(`unexpected “${tokens[p].t === "n" ? tokens[p].v : tokens[p].v ?? tokens[p].t}”`);
    return v;
}

// -> { ok: true, value: number, text: "42" } or { ok: false, error: "…" }
function evaluate(src) {
    try {
        const v = parse(tokenize(src));
        if (!isFinite(v)) return { ok: false, error: "not a finite number" };
        return { ok: true, value: v, text: format(v) };
    } catch (e) {
        return { ok: false, error: e.message };
    }
}

function format(v) {
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
    const r = parseFloat(v.toPrecision(12));
    return Math.abs(r) >= 1e15 || (Math.abs(r) < 1e-6 && r !== 0) ? r.toExponential(6) : String(r);
}
