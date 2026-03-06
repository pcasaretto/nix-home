/**
 * Tests for vim-mode pure functions.
 *
 * Run with: node --experimental-strip-types --no-warnings --test vim-mode.test.ts
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
	findNextWordStart,
	findWordEnd,
	findPrevWordStart,
	findPrevWORDStart,
	findCharForward,
	findCharBackward,
	findFirstNonWhitespaceCol,
	computeOperatorRange,
	extractRange,
	applyDelete,
	isWhitespace,
	isPunctuation,
	isWordChar,
} from "./vim-core.ts";

// ─── Character classification ────────────────────────────────────────

describe("character classification", () => {
	it("classifies whitespace", () => {
		assert.ok(isWhitespace(" "));
		assert.ok(isWhitespace("\t"));
		assert.ok(!isWhitespace("a"));
		assert.ok(!isWhitespace("."));
	});

	it("classifies punctuation", () => {
		assert.ok(isPunctuation("."));
		assert.ok(isPunctuation("("));
		assert.ok(isPunctuation("+"));
		assert.ok(!isPunctuation("a"));
		assert.ok(!isPunctuation(" "));
	});

	it("classifies word characters", () => {
		assert.ok(isWordChar("a"));
		assert.ok(isWordChar("Z"));
		assert.ok(isWordChar("0"));
		assert.ok(isWordChar("_"));
		assert.ok(!isWordChar(" "));
		assert.ok(!isWordChar("."));
	});
});

describe("findFirstNonWhitespaceCol", () => {
	it("returns first non-whitespace column", () => {
		assert.strictEqual(findFirstNonWhitespaceCol(["   abc"], 0), 3);
	});

	it("returns 0 for non-indented line", () => {
		assert.strictEqual(findFirstNonWhitespaceCol(["abc"], 0), 0);
	});

	it("returns line length for whitespace-only line", () => {
		assert.strictEqual(findFirstNonWhitespaceCol(["   "], 0), 3);
	});
});

// ─── findNextWordStart (w motion) ────────────────────────────────────

describe("findNextWordStart", () => {
	it("moves from start of word to start of next word", () => {
		const result = findNextWordStart(["hello world"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});

	it("moves from middle of word to start of next word", () => {
		const result = findNextWordStart(["hello world"], 0, 3);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});

	it("skips multiple spaces", () => {
		const result = findNextWordStart(["foo  bar"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 5 });
	});

	it("stops at punctuation boundary", () => {
		const result = findNextWordStart(["foo.bar"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 3 });
	});

	it("moves from punctuation to next word", () => {
		const result = findNextWordStart(["foo.bar"], 0, 3);
		assert.deepStrictEqual(result, { line: 0, col: 4 });
	});

	it("crosses line boundary from end of word", () => {
		const result = findNextWordStart(["end", "next"], 0, 3);
		assert.deepStrictEqual(result, { line: 1, col: 0 });
	});

	it("w from start of only word on line crosses to next line", () => {
		const result = findNextWordStart(["end", "next"], 0, 0);
		// "end" fills the whole line, w skips past it and crosses to next line
		assert.deepStrictEqual(result, { line: 1, col: 0 });
	});

	it("skips empty lines", () => {
		const result = findNextWordStart(["hello", "", "world"], 0, 5);
		assert.deepStrictEqual(result, { line: 2, col: 0 });
	});

	it("stays at end of last line when no more words", () => {
		const result = findNextWordStart(["hello"], 0, 3);
		assert.deepStrictEqual(result, { line: 0, col: 5 });
	});

	it("handles single character words", () => {
		const result = findNextWordStart(["a b c"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 2 });
	});

	it("starts from whitespace", () => {
		const result = findNextWordStart(["  hello"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 2 });
	});

	it("handles empty lines array", () => {
		const result = findNextWordStart([], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("handles single empty line", () => {
		const result = findNextWordStart([""], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("handles only whitespace", () => {
		const result = findNextWordStart(["   "], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 3 });
	});
});

// ─── findWordEnd (e motion) ─────────────────────────────────────────

describe("findWordEnd", () => {
	it("from start of word to end of word", () => {
		const result = findWordEnd(["hello world"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 4 });
	});

	it("from end of word to end of next word", () => {
		const result = findWordEnd(["hello world"], 0, 4);
		assert.deepStrictEqual(result, { line: 0, col: 10 });
	});

	it("stops at word boundary before punctuation", () => {
		const result = findWordEnd(["foo.bar"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 2 });
	});

	it("from punctuation to end of next word class", () => {
		// At col 2 (last char of "foo"), e moves forward one, lands on ".",
		// which is punctuation — it's a 1-char class run, so end = col 3
		const result = findWordEnd(["foo.bar"], 0, 2);
		assert.deepStrictEqual(result, { line: 0, col: 3 });
	});

	it("crosses line boundary", () => {
		const result = findWordEnd(["hi", "world"], 0, 1);
		assert.deepStrictEqual(result, { line: 1, col: 4 });
	});

	it("from mid-word to end of word", () => {
		const result = findWordEnd(["hello"], 0, 1);
		assert.deepStrictEqual(result, { line: 0, col: 4 });
	});

	it("handles single char words", () => {
		const result = findWordEnd(["a b c"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 2 });
	});

	it("handles empty lines", () => {
		const result = findWordEnd([], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});
});

// ─── findPrevWordStart (b motion) ────────────────────────────────────

describe("findPrevWordStart", () => {
	it("b from start of second word", () => {
		const result = findPrevWordStart(["hello world"], 0, 6);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b from mid-word", () => {
		const result = findPrevWordStart(["hello world"], 0, 8);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});

	it("b at start of buffer", () => {
		const result = findPrevWordStart(["hello world"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b skips multiple spaces", () => {
		const result = findPrevWordStart(["foo  bar"], 0, 5);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b stops at punctuation", () => {
		const result = findPrevWordStart(["foo.bar"], 0, 4);
		assert.deepStrictEqual(result, { line: 0, col: 3 });
	});

	it("b from punct to prev word", () => {
		const result = findPrevWordStart(["foo.bar"], 0, 3);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b crosses line boundary", () => {
		const result = findPrevWordStart(["first", "second"], 1, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b skips empty lines", () => {
		const result = findPrevWordStart(["first", "", "third"], 2, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b with single-char words", () => {
		const result = findPrevWordStart(["a b c"], 0, 4);
		assert.deepStrictEqual(result, { line: 0, col: 2 });
	});

	it("handles empty lines array", () => {
		const result = findPrevWordStart([], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("handles single empty line", () => {
		const result = findPrevWordStart([""], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b from col 1 on first line", () => {
		const result = findPrevWordStart(["hello"], 0, 1);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b crosses line to end of previous word", () => {
		const result = findPrevWordStart(["hello world", "next"], 1, 0);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});
});

// ─── findPrevWORDStart (B motion) ────────────────────────────────────

describe("findPrevWORDStart", () => {
	it("B from start of second WORD", () => {
		const result = findPrevWORDStart(["hello world"], 0, 6);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B from mid-WORD", () => {
		const result = findPrevWORDStart(["hello world"], 0, 8);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});

	it("B treats punctuation as part of WORD (key difference from b)", () => {
		// b would stop at the '.', but B skips over it
		const result = findPrevWORDStart(["foo.bar baz"], 0, 8);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B from punctuation stays in same WORD", () => {
		// cursor on 'b' at col 4 in "foo.bar", B goes to start of WORD
		const result = findPrevWORDStart(["foo.bar"], 0, 4);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("b stops at punctuation boundary (contrast with B)", () => {
		// b from col 4 ('b') in "foo.bar" stops at '.' (col 3)
		const result = findPrevWordStart(["foo.bar"], 0, 4);
		assert.deepStrictEqual(result, { line: 0, col: 3 });
	});

	it("B at start of buffer", () => {
		const result = findPrevWORDStart(["hello"], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B skips multiple spaces", () => {
		const result = findPrevWORDStart(["foo  bar"], 0, 5);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B crosses line boundary", () => {
		const result = findPrevWORDStart(["first", "second"], 1, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B skips empty lines", () => {
		const result = findPrevWORDStart(["first", "", "third"], 2, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("B crosses line to end of previous WORD", () => {
		const result = findPrevWORDStart(["hello world", "next"], 1, 0);
		assert.deepStrictEqual(result, { line: 0, col: 6 });
	});

	it("B with mixed punctuation WORD", () => {
		// "a.b+c" is one WORD, "x" is another
		const result = findPrevWORDStart(["a.b+c x"], 0, 6);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("handles empty lines array", () => {
		const result = findPrevWORDStart([], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});

	it("handles single empty line", () => {
		const result = findPrevWORDStart([""], 0, 0);
		assert.deepStrictEqual(result, { line: 0, col: 0 });
	});
});

// ─── computeOperatorRange ───────────────────────────────────────────

describe("computeOperatorRange", () => {
	describe("w motion", () => {
		it("dw at start of line", () => {
			const range = computeOperatorRange(["hello world"], 0, 0, "w");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 6,
				linewise: false,
			});
		});

		it("dw at last word goes to end of line", () => {
			const range = computeOperatorRange(["hello world"], 0, 6, "w");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 6,
				endLine: 0, endCol: 11,
				linewise: false,
			});
		});

		it("d2w deletes two words", () => {
			const range = computeOperatorRange(["one two three"], 0, 0, "w", 2);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 8,
				linewise: false,
			});
		});
	});

	describe("e motion", () => {
		it("de at start of word (inclusive)", () => {
			const range = computeOperatorRange(["hello world"], 0, 0, "e");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 5,
				linewise: false,
			});
		});
	});

	describe("$ motion", () => {
		it("d$ deletes to end of line", () => {
			const range = computeOperatorRange(["hello world"], 0, 6, "$");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 6,
				endLine: 0, endCol: 11,
				linewise: false,
			});
		});
	});

	describe("0 motion", () => {
		it("d0 deletes to start of line", () => {
			const range = computeOperatorRange(["hello world"], 0, 6, "0");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 6,
				linewise: false,
			});
		});
	});

	describe("^ motion", () => {
		it("d^ deletes to first non-whitespace", () => {
			const range = computeOperatorRange(["   hello world"], 0, 8, "^");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 3,
				endLine: 0, endCol: 8,
				linewise: false,
			});
		});
	});

	describe("linewise (dd, cc)", () => {
		it("dd deletes one line", () => {
			const range = computeOperatorRange(["hello", "world"], 0, 0, "d");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 1, endCol: 0,
				linewise: true,
			});
		});

		it("2dd deletes two lines", () => {
			const range = computeOperatorRange(["a", "b", "c"], 0, 0, "d", 2);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 2, endCol: 0,
				linewise: true,
			});
		});

		it("dd clamps to end of file", () => {
			const range = computeOperatorRange(["a", "b"], 0, 0, "d", 5);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 2, endCol: 0,
				linewise: true,
			});
		});
	});

	describe("h motion", () => {
		it("dh deletes one char left", () => {
			const range = computeOperatorRange(["hello"], 0, 3, "h");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 2,
				endLine: 0, endCol: 3,
				linewise: false,
			});
		});
	});

	describe("l motion", () => {
		it("dl deletes one char right", () => {
			const range = computeOperatorRange(["hello"], 0, 2, "l");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 2,
				endLine: 0, endCol: 3,
				linewise: false,
			});
		});
	});

	describe("b motion", () => {
		it("db deletes backward one word", () => {
			const range = computeOperatorRange(["hello world"], 0, 6, "b");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 6,
				linewise: false,
			});
		});

		it("d2b deletes backward two words", () => {
			const range = computeOperatorRange(["one two three"], 0, 8, "b", 2);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 8,
				linewise: false,
			});
		});
	});

	describe("B motion", () => {
		it("dB deletes backward one WORD (crosses punctuation)", () => {
			const range = computeOperatorRange(["foo.bar baz"], 0, 8, "B");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 0, endCol: 8,
				linewise: false,
			});
		});

		it("db stops at punctuation (contrast with dB)", () => {
			const range = computeOperatorRange(["foo.bar baz"], 0, 8, "b");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 4,
				endLine: 0, endCol: 8,
				linewise: false,
			});
		});
	});

	describe("j motion", () => {
		it("dj deletes current line and line below (linewise)", () => {
			const range = computeOperatorRange(["a", "b", "c", "d"], 1, 0, "j");
			assert.deepStrictEqual(range, {
				startLine: 1, startCol: 0,
				endLine: 3, endCol: 0,
				linewise: true,
			});
		});

		it("d2j deletes current line and 2 lines below", () => {
			const range = computeOperatorRange(["a", "b", "c", "d"], 0, 0, "j", 2);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 3, endCol: 0,
				linewise: true,
			});
		});

		it("dj clamps to end of file", () => {
			const range = computeOperatorRange(["a", "b"], 1, 0, "j");
			assert.deepStrictEqual(range, {
				startLine: 1, startCol: 0,
				endLine: 2, endCol: 0,
				linewise: true,
			});
		});
	});

	describe("k motion", () => {
		it("dk deletes current line and line above (linewise)", () => {
			const range = computeOperatorRange(["a", "b", "c", "d"], 2, 0, "k");
			assert.deepStrictEqual(range, {
				startLine: 1, startCol: 0,
				endLine: 3, endCol: 0,
				linewise: true,
			});
		});

		it("d2k deletes current line and 2 lines above", () => {
			const range = computeOperatorRange(["a", "b", "c", "d"], 2, 0, "k", 2);
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 3, endCol: 0,
				linewise: true,
			});
		});

		it("dk clamps to beginning of file", () => {
			const range = computeOperatorRange(["a", "b"], 0, 0, "k");
			assert.deepStrictEqual(range, {
				startLine: 0, startCol: 0,
				endLine: 1, endCol: 0,
				linewise: true,
			});
		});
	});

	it("returns null for unknown motion", () => {
		const range = computeOperatorRange(["hello"], 0, 0, "z");
		assert.strictEqual(range, null);
	});
});

// ─── extractRange ───────────────────────────────────────────────────

describe("extractRange", () => {
	it("extracts single-line charwise range", () => {
		const text = extractRange(["hello world"], {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 5,
			linewise: false,
		});
		assert.strictEqual(text, "hello");
	});

	it("extracts multi-line charwise range", () => {
		const text = extractRange(["abc", "def", "ghi"], {
			startLine: 0, startCol: 1,
			endLine: 2, endCol: 1,
			linewise: false,
		});
		assert.strictEqual(text, "bc\ndef\ng");
	});

	it("extracts linewise range", () => {
		const text = extractRange(["a", "b", "c", "d"], {
			startLine: 1, startCol: 0,
			endLine: 3, endCol: 0,
			linewise: true,
		});
		assert.strictEqual(text, "b\nc");
	});
});

// ─── applyDelete ────────────────────────────────────────────────────

describe("applyDelete", () => {
	it("deletes characters on same line", () => {
		const result = applyDelete(["hello world"], {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 6,
			linewise: false,
		});
		assert.deepStrictEqual(result.newLines, ["world"]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("deletes to end of line", () => {
		const result = applyDelete(["hello world"], {
			startLine: 0, startCol: 5,
			endLine: 0, endCol: 11,
			linewise: false,
		});
		assert.deepStrictEqual(result.newLines, ["hello"]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 5);
	});

	it("linewise delete of single line", () => {
		const result = applyDelete(["hello", "world"], {
			startLine: 0, startCol: 0,
			endLine: 1, endCol: 0,
			linewise: true,
		});
		assert.deepStrictEqual(result.newLines, ["world"]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("linewise delete of all lines leaves empty line", () => {
		const result = applyDelete(["hello"], {
			startLine: 0, startCol: 0,
			endLine: 1, endCol: 0,
			linewise: true,
		});
		assert.deepStrictEqual(result.newLines, [""]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("linewise delete of multiple lines", () => {
		const result = applyDelete(["a", "b", "c", "d"], {
			startLine: 1, startCol: 0,
			endLine: 3, endCol: 0,
			linewise: true,
		});
		assert.deepStrictEqual(result.newLines, ["a", "d"]);
		assert.strictEqual(result.cursorLine, 1);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("character delete in middle of line", () => {
		const result = applyDelete(["hello world"], {
			startLine: 0, startCol: 2,
			endLine: 0, endCol: 8,
			linewise: false,
		});
		assert.deepStrictEqual(result.newLines, ["herld"]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 2);
	});

	it("does not mutate original array", () => {
		const lines = ["hello", "world"];
		const range = computeOperatorRange(lines, 0, 0, "d")!;
		applyDelete(lines, range);
		assert.deepStrictEqual(lines, ["hello", "world"]);
	});

	it("multi-line character delete merges lines", () => {
		const result = applyDelete(["abc", "def", "ghi"], {
			startLine: 0, startCol: 1,
			endLine: 2, endCol: 1,
			linewise: false,
		});
		assert.deepStrictEqual(result.newLines, ["ahi"]);
		assert.strictEqual(result.cursorLine, 0);
		assert.strictEqual(result.cursorCol, 1);
	});
});

// ─── Integration: operator + motion → delete ────────────────────────

describe("integration: operator + motion → applyDelete", () => {
	it("dw: delete first word and space", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "w")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["world"]);
	});

	it("de: delete to end of word (inclusive)", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "e")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, [" world"]);
	});

	it("d$: delete to end of line", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 5, "$")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["hello"]);
	});

	it("d0: delete to start of line", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 6, "0")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["world"]);
	});

	it("d^: delete to first non-whitespace", () => {
		const lines = ["   hello world"];
		const range = computeOperatorRange(lines, 0, 8, "^")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["    world"]);
	});

	it("dd: delete entire line", () => {
		const lines = ["first", "second", "third"];
		const range = computeOperatorRange(lines, 1, 0, "d")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["first", "third"]);
	});

	it("2dd: delete two lines", () => {
		const lines = ["a", "b", "c", "d"];
		const range = computeOperatorRange(lines, 0, 0, "d", 2)!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["c", "d"]);
	});

	it("d2w: delete next 2 words", () => {
		const lines = ["one two three four"];
		const range = computeOperatorRange(lines, 0, 0, "w", 2)!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["three four"]);
	});

	it("dw on last word of line deletes to end", () => {
		const lines = ["foo bar"];
		const range = computeOperatorRange(lines, 0, 4, "w")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["foo "]);
	});

	it("dw with punctuation", () => {
		const lines = ["foo.bar baz"];
		const range = computeOperatorRange(lines, 0, 0, "w")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, [".bar baz"]);
	});

	it("de with punctuation boundary", () => {
		const lines = ["foo.bar"];
		const range = computeOperatorRange(lines, 0, 0, "e")!;
		const result = applyDelete(lines, range);
		// "e" from col 0 goes to col 2 (end of "foo"), inclusive → delete cols 0-2
		assert.deepStrictEqual(result.newLines, [".bar"]);
	});

	it("dh: delete one char to the left", () => {
		const lines = ["hello"];
		const range = computeOperatorRange(lines, 0, 3, "h")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["helo"]);
		assert.strictEqual(result.cursorCol, 2);
	});

	it("dl: delete one char to the right", () => {
		const lines = ["hello"];
		const range = computeOperatorRange(lines, 0, 2, "l")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["helo"]);
		assert.strictEqual(result.cursorCol, 2);
	});

	it("d3h: delete 3 chars to the left", () => {
		const lines = ["hello"];
		const range = computeOperatorRange(lines, 0, 4, "h", 3)!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["ho"]);
		assert.strictEqual(result.cursorCol, 1);
	});

	it("dj: delete two lines", () => {
		const lines = ["a", "b", "c", "d"];
		const range = computeOperatorRange(lines, 1, 0, "j")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["a", "d"]);
	});

	it("d2j: delete three lines", () => {
		const lines = ["a", "b", "c", "d"];
		const range = computeOperatorRange(lines, 0, 0, "j", 2)!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["d"]);
	});

	it("dk: delete two lines", () => {
		const lines = ["a", "b", "c", "d"];
		const range = computeOperatorRange(lines, 2, 0, "k")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["a", "d"]);
	});

	it("cc: change (delete) entire line", () => {
		const lines = ["first", "second", "third"];
		const range = computeOperatorRange(lines, 1, 3, "c")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["first", "third"]);
	});
});

// ─── Integration: b motion (backward word delete) ───────────────────

describe("integration: b motion → applyDelete", () => {
	it("db: delete backward one word", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 6, "b")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["world"]);
	});

	it("d2b: delete backward two words", () => {
		const lines = ["one two three"];
		const range = computeOperatorRange(lines, 0, 8, "b", 2)!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["three"]);
	});

	it("cb: change backward one word (delete, cursor at start)", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 6, "b")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["world"]);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("db with punctuation", () => {
		const lines = ["foo.bar"];
		const range = computeOperatorRange(lines, 0, 4, "b")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["foobar"]);
	});
});

describe("integration: B motion → applyDelete", () => {
	it("dB: delete backward one WORD (crosses punctuation)", () => {
		const lines = ["foo.bar baz"];
		const range = computeOperatorRange(lines, 0, 8, "B")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["baz"]);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("dB vs db with punctuation", () => {
		// db from col 8 stops at 'bar' (col 4), dB goes all the way to col 0
		const lines = ["foo.bar baz"];
		const dbRange = computeOperatorRange(lines, 0, 8, "b")!;
		const dbResult = applyDelete(lines, dbRange);
		assert.deepStrictEqual(dbResult.newLines, ["foo.baz"]);

		const dBRange = computeOperatorRange(lines, 0, 8, "B")!;
		const dBResult = applyDelete(lines, dBRange);
		assert.deepStrictEqual(dBResult.newLines, ["baz"]);
	});
});

// ─── Repeated motions ───────────────────────────────────────────────

describe("repeated motions (count)", () => {
	it("3w moves 3 words", () => {
		const lines = ["one two three four five"];
		let pos = { line: 0, col: 0 };
		for (let i = 0; i < 3; i++) {
			pos = findNextWordStart(lines, pos.line, pos.col);
		}
		assert.deepStrictEqual(pos, { line: 0, col: 14 }); // "four"
	});

	it("2e moves to end of 2nd word", () => {
		const lines = ["one two three"];
		let pos = { line: 0, col: 0 };
		for (let i = 0; i < 2; i++) {
			pos = findWordEnd(lines, pos.line, pos.col);
		}
		assert.deepStrictEqual(pos, { line: 0, col: 6 }); // end of "two"
	});

	it("w across multiple lines", () => {
		const lines = ["end", "of", "file"];
		let pos = { line: 0, col: 0 };
		// w from "end" → past word, crosses to "of"
		pos = findNextWordStart(lines, pos.line, pos.col);
		// "end" fills the line → crosses to next line
		assert.deepStrictEqual(pos, { line: 1, col: 0 }); // "of"
		pos = findNextWordStart(lines, pos.line, pos.col);
		assert.deepStrictEqual(pos, { line: 2, col: 0 }); // "file"
		pos = findNextWordStart(lines, pos.line, pos.col);
		assert.deepStrictEqual(pos, { line: 2, col: 4 }); // end of text
	});
});

// ─── findCharForward (f motion) ─────────────────────────────────────

describe("findCharForward", () => {
	it("finds next occurrence of char", () => {
		const result = findCharForward(["hello world"], 0, 0, "o");
		assert.strictEqual(result, 4);
	});

	it("finds char starting after current col", () => {
		const result = findCharForward(["abcabc"], 0, 0, "b");
		assert.strictEqual(result, 1);
	});

	it("skips char at current col", () => {
		const result = findCharForward(["abcabc"], 0, 1, "b");
		assert.strictEqual(result, 4);
	});

	it("finds nth occurrence with count", () => {
		const result = findCharForward(["abcabcabc"], 0, 0, "a", 2);
		assert.strictEqual(result, 6);
	});

	it("returns -1 when char not found", () => {
		const result = findCharForward(["hello"], 0, 0, "z");
		assert.strictEqual(result, -1);
	});

	it("returns -1 when count exceeds occurrences", () => {
		const result = findCharForward(["abcabc"], 0, 0, "a", 5);
		assert.strictEqual(result, -1);
	});

	it("returns -1 at end of line", () => {
		const result = findCharForward(["abc"], 0, 2, "x");
		assert.strictEqual(result, -1);
	});

	it("finds char on specific line", () => {
		const result = findCharForward(["abc", "def", "ghi"], 1, 0, "f");
		assert.strictEqual(result, 2);
	});

	it("handles empty lines", () => {
		const result = findCharForward([""], 0, 0, "a");
		assert.strictEqual(result, -1);
	});

	it("finds space character", () => {
		const result = findCharForward(["hello world"], 0, 0, " ");
		assert.strictEqual(result, 5);
	});
});

// ─── findCharBackward (F motion) ────────────────────────────────────

describe("findCharBackward", () => {
	it("finds previous occurrence of char", () => {
		const result = findCharBackward(["hello world"], 0, 10, "o");
		assert.strictEqual(result, 7);
	});

	it("skips char at current col", () => {
		const result = findCharBackward(["abcabc"], 0, 4, "b");
		assert.strictEqual(result, 1);
	});

	it("finds nth occurrence backward with count", () => {
		const result = findCharBackward(["abcabcabc"], 0, 8, "a", 2);
		assert.strictEqual(result, 3);
	});

	it("returns -1 when char not found", () => {
		const result = findCharBackward(["hello"], 0, 4, "z");
		assert.strictEqual(result, -1);
	});

	it("returns -1 when count exceeds occurrences", () => {
		const result = findCharBackward(["abcabc"], 0, 5, "a", 5);
		assert.strictEqual(result, -1);
	});

	it("returns -1 at start of line", () => {
		const result = findCharBackward(["abc"], 0, 0, "a");
		assert.strictEqual(result, -1);
	});

	it("finds char on specific line", () => {
		const result = findCharBackward(["abc", "def", "ghi"], 1, 2, "d");
		assert.strictEqual(result, 0);
	});

	it("handles empty lines", () => {
		const result = findCharBackward([""], 0, 0, "a");
		assert.strictEqual(result, -1);
	});
});

// ─── computeOperatorRange with f/t/F/T ──────────────────────────────

describe("computeOperatorRange: f motion", () => {
	it("df{char}: range from cursor to found char (inclusive)", () => {
		const range = computeOperatorRange(["hello world"], 0, 0, "f", 1, "o");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 5, // inclusive of 'o' at col 4
			linewise: false,
		});
	});

	it("d2f{char}: finds the 2nd occurrence", () => {
		const range = computeOperatorRange(["abcabcabc"], 0, 0, "f", 2, "a");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 7, // 2nd 'a' at col 6, inclusive
			linewise: false,
		});
	});

	it("df{char}: returns null when char not found", () => {
		const range = computeOperatorRange(["hello"], 0, 0, "f", 1, "z");
		assert.strictEqual(range, null);
	});

	it("df{char}: returns null without targetChar", () => {
		const range = computeOperatorRange(["hello"], 0, 0, "f");
		assert.strictEqual(range, null);
	});
});

describe("computeOperatorRange: t motion", () => {
	it("dt{char}: range from cursor up to (not including) found char", () => {
		const range = computeOperatorRange(["hello world"], 0, 0, "t", 1, "o");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 4, // up to but not including 'o' at col 4
			linewise: false,
		});
	});

	it("dt{char}: returns null when char is immediately next", () => {
		// 'e' is at col 1, immediately next to cursor at col 0
		const range = computeOperatorRange(["hello"], 0, 0, "t", 1, "e");
		assert.strictEqual(range, null);
	});

	it("dt{char}: works when there is a gap", () => {
		// cursor at 0, 'l' at col 2 — gap of 1
		const range = computeOperatorRange(["hello"], 0, 0, "t", 1, "l");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 0,
			endLine: 0, endCol: 2, // up to but not including 'l' at col 2
			linewise: false,
		});
	});

	it("dt{char}: returns null when char not found", () => {
		const range = computeOperatorRange(["hello"], 0, 0, "t", 1, "z");
		assert.strictEqual(range, null);
	});
});

describe("computeOperatorRange: F motion", () => {
	it("dF{char}: range from found char to cursor (exclusive of cursor)", () => {
		const range = computeOperatorRange(["hello world"], 0, 7, "F", 1, "l");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 3, // 'l' found at col 3
			endLine: 0, endCol: 7, // exclusive of cursor at col 7
			linewise: false,
		});
	});

	it("d2F{char}: finds the 2nd occurrence backward", () => {
		const range = computeOperatorRange(["abcabcabc"], 0, 8, "F", 2, "a");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 3, // 2nd 'a' backward at col 3
			endLine: 0, endCol: 8,
			linewise: false,
		});
	});

	it("dF{char}: returns null when char not found", () => {
		const range = computeOperatorRange(["hello"], 0, 4, "F", 1, "z");
		assert.strictEqual(range, null);
	});
});

describe("computeOperatorRange: T motion", () => {
	it("dT{char}: range from after found char to cursor (exclusive of both)", () => {
		// cursor at 7, find 'l' backward at col 3. T excludes found char → startCol = 4
		const range = computeOperatorRange(["hello world"], 0, 7, "T", 1, "l");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 4, // after 'l' at col 3
			endLine: 0, endCol: 7, // exclusive of cursor
			linewise: false,
		});
	});

	it("dT{char}: returns null when char is immediately before cursor", () => {
		// cursor at 2, 'e' at col 1 → T target = col 2 = cursor, no movement
		const range = computeOperatorRange(["hello"], 0, 2, "T", 1, "e");
		assert.strictEqual(range, null);
	});

	it("dT{char}: works when there is a gap", () => {
		// cursor at 4, 'e' at col 1. T target = col 2, range [2, 4)
		const range = computeOperatorRange(["hello"], 0, 4, "T", 1, "e");
		assert.deepStrictEqual(range, {
			startLine: 0, startCol: 2,
			endLine: 0, endCol: 4,
			linewise: false,
		});
	});

	it("dT{char}: returns null when char not found", () => {
		const range = computeOperatorRange(["hello"], 0, 4, "T", 1, "z");
		assert.strictEqual(range, null);
	});
});

// ─── Integration: f/t/F/T operator + motion → delete ────────────────

describe("integration: f/t/F/T → applyDelete", () => {
	it("dfo: delete from cursor through next 'o' (inclusive)", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "f", 1, "o")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, [" world"]);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("dto: delete from cursor up to (not including) 'o'", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "t", 1, "o")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["o world"]);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("dFl: delete backward from 'l' to cursor (exclusive of cursor char)", () => {
		// cursor at col 7 ('o'), F finds 'l' at col 3
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 7, "F", 1, "l")!;
		const result = applyDelete(lines, range);
		// deletes cols 3-6 ("lo w"), keeps col 0-2 ("hel") and col 7+ ("orld")
		assert.deepStrictEqual(result.newLines, ["helorld"]);
		assert.strictEqual(result.cursorCol, 3);
	});

	it("dTl: delete backward from after 'l' to cursor (exclusive of both)", () => {
		// cursor at col 7, T finds 'l' at col 3, start at col 4
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 7, "T", 1, "l")!;
		const result = applyDelete(lines, range);
		// deletes cols 4-6 ("o w"), keeps "hell" and "orld"
		assert.deepStrictEqual(result.newLines, ["hellorld"]);
		assert.strictEqual(result.cursorCol, 4);
	});

	it("d2fo: delete through 2nd 'o'", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "f", 2, "o")!;
		const result = applyDelete(lines, range);
		// 2nd 'o' is at col 7, delete [0, 8)
		assert.deepStrictEqual(result.newLines, ["rld"]);
		assert.strictEqual(result.cursorCol, 0);
	});

	it("dfa: does nothing when char not found", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "f", 1, "z");
		assert.strictEqual(range, null);
	});

	it("cf{char}: change through found char (delete + enter insert)", () => {
		const lines = ["hello world"];
		const range = computeOperatorRange(lines, 0, 0, "f", 1, " ")!;
		const result = applyDelete(lines, range);
		assert.deepStrictEqual(result.newLines, ["world"]);
		assert.strictEqual(result.cursorCol, 0);
	});
});
