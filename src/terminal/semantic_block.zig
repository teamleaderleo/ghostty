const std = @import("std");
const PageList = @import("PageList.zig");
const highlight = @import("highlight.zig");

const max_prompt_scan_rows = 2048;

/// Return the full shell-integration block containing `at`:
/// the first prompt row through the row immediately before the next prompt.
///
/// This is intentionally read-only and returns untracked pins. Callers must
/// hold the terminal state stable while using the result. The backward lookup
/// is bounded so a hover inside a TUI cannot walk an unbounded scrollback when
/// no nearby shell prompt metadata exists.
pub fn bounds(pages: *const PageList, at: PageList.Pin) ?highlight.Untracked {
    const screen_top = pages.getTopLeft(.screen);
    const screen_bottom = pages.getBottomRight(.screen) orelse return null;
    const scan_top = at.up(max_prompt_scan_rows) orelse screen_top;

    var prior_prompts = at.promptIterator(.left_up, scan_top);
    const start = prior_prompts.next() orelse return null;

    var later_prompts = start.promptIterator(.right_down, screen_bottom);
    const current = later_prompts.next() orelse return null;
    if (!current.eql(start)) return null;

    const end = if (later_prompts.next()) |next| end: {
        var prior = next.up(1) orelse return null;
        prior.x = prior.node.cols() - 1;
        break :end prior;
    } else screen_bottom;

    return .{
        .start = start.left(start.x),
        .end = end,
    };
}

test "semantic block spans prompt until next prompt" {
    const testing = std.testing;

    var pages = try PageList.init(testing.allocator, .{
        .cols = 8,
        .rows = 4,
    });
    defer pages.deinit();

    const first_prompt = pages.pin(.{ .active = .{ .x = 0, .y = 0 } }).?;
    first_prompt.rowAndCell().row.semantic_prompt = .prompt;

    const second_prompt = pages.pin(.{ .active = .{ .x = 0, .y = 3 } }).?;
    second_prompt.rowAndCell().row.semantic_prompt = .prompt;

    const hovered = pages.pin(.{ .active = .{ .x = 4, .y = 2 } }).?;
    const result = bounds(&pages, hovered).?;

    try testing.expect(result.start.eql(first_prompt));
    var expected_end = second_prompt.up(1).?;
    expected_end.x = expected_end.node.cols() - 1;
    try testing.expect(result.end.eql(expected_end));
}

test "semantic block uses screen bottom for latest prompt" {
    const testing = std.testing;

    var pages = try PageList.init(testing.allocator, .{
        .cols = 8,
        .rows = 4,
    });
    defer pages.deinit();

    const prompt = pages.pin(.{ .active = .{ .x = 0, .y = 1 } }).?;
    prompt.rowAndCell().row.semantic_prompt = .prompt;

    const hovered = pages.pin(.{ .active = .{ .x = 2, .y = 3 } }).?;
    const result = bounds(&pages, hovered).?;

    try testing.expect(result.start.eql(prompt));
    try testing.expect(result.end.eql(pages.getBottomRight(.screen).?));
}
