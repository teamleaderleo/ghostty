const std = @import("std");
const apprt = @import("apprt.zig");
const global = @import("global.zig");
const terminal = @import("terminal/main.zig");
const semantic_block = @import("terminal/semantic_block.zig");

/// ABI-compatible with ghostty_text_s. The buffer is allocated by Ghostty and
/// is released with the existing ghostty_surface_free_text API.
const Text = extern struct {
    tl_px_x: f64,
    tl_px_y: f64,
    offset_start: u32,
    offset_len: u32,
    text: ?[*:0]const u8,
    text_len: usize,
};

/// Read the complete semantic terminal block under a surface-space point.
/// Coordinates use the same top-left-origin convention as mouse-position input.
pub export fn ghostty_surface_read_semantic_block(
    surface: *apprt.Surface,
    x: f64,
    y: f64,
    result: *Text,
) bool {
    const core_surface = &surface.core_surface;
    const coordinate = core_surface.posToViewport(x, y);
    if (coordinate.x < 0 or coordinate.y < 0) return false;

    core_surface.renderer_state.mutex.lockUncancelable(global.io());
    defer core_surface.renderer_state.mutex.unlock(global.io());

    const screen = &core_surface.renderer_state.terminal.screens.active;
    const pages = &screen.pages;
    const at = pages.pin(.{ .viewport = .{
        .x = coordinate.x,
        .y = coordinate.y,
    } }) orelse return false;

    const block = semantic_block.bounds(pages, at) orelse return false;
    const selection: terminal.Selection = .{
        .bounds = .{ .untracked = block },
        .rectangle = false,
    };

    const text = core_surface.dumpTextLocked(
        global.alloc(),
        selection,
    ) catch |err| {
        std.log.warn("error reading semantic block text err={}", .{err});
        return false;
    };

    const viewport = text.viewport orelse .{
        .tl_px_x = -1,
        .tl_px_y = -1,
        .offset_start = 0,
        .offset_len = 0,
    };

    result.* = .{
        .tl_px_x = viewport.tl_px_x,
        .tl_px_y = viewport.tl_px_y,
        .offset_start = viewport.offset_start,
        .offset_len = viewport.offset_len,
        .text = text.text.ptr,
        .text_len = text.text.len,
    };
    return true;
}
