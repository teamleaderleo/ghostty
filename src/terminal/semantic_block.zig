const std = @import("std");
const PageList = @import("PageList.zig");
const highlight = @import("highlight.zig");

const max_prompt_scan_rows = 2048;

pub fn bounds(pages: *const PageList, at: PageList.Pin) ?highlight.Untracked {
    const screen_top = pages.getTopLeft(.screen);
    const screen_bottom = pages.getBottomRight(.screen) orelse return null;
    const scan_top = at.up(max_prompt_scan_rows) orelse screen_top;

    var prior_prompts = at.promptIterator(.left_up, scan_top);
    const start = prior_prompts.next() orelse return null;

    var later_prompts = start.promptIterator(.right_down, screen_bottom);
    const current = later_prompts.next() orelse return null;
    if (!current.eql(start)) return null;

    const next = later_prompts.next() orelse return null;
    var end = next.up(1) orelse return null;
    end.x = end.node.cols() - 1;

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

test "latest prompt is not a completed block" {
    const testing = std.testing;

    var pages = try PageList.init(testing.allocator, .{
        .cols = 8,
        .rows = 4,
    });
    defer pages.deinit();

    const prompt = pages.pin(.{ .active = .{ .x = 0, .y = 1 } }).?;
    prompt.rowAndCell().row.semantic_prompt = .prompt;

    const hovered = pages.pin(.{ .active = .{ .x = 2, .y = 3 } }).?;
    try testing.expect(bounds(&pages, hovered) == null);
}
