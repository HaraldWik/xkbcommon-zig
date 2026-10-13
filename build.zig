const std = @import("std");

/// Import the `Translator` helper from the `translate_c` dependency.
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libxkbcommon = b.dependency("libxkbcommon", .{});
    const libxml2 = b.dependency("libxml2", .{ .target = target, .optimize = optimize });

    const xkb_config_root = b.option([]const u8, "xkb-config-root", "The XKB config root [default=xkeyboard-config install path]");
    const xkb_config_versioned_extensions_path = b.option([]const u8, "xkb-config-versioned-extensions-path", "Lookup path for system-wide XKB versioned data extensions [default=xkeyboard-config install path + .d]");
    const xkb_config_unversioned_extensions_path = b.option([]const u8, "xkb-config-unversioned-extensions-path", "Lookup path for system-wide XKB unversioned data extensions [default=xkeyboard-config install path - version + .d]");
    const xkb_config_extra_path = b.option([]const u8, "xkb-config-extra-path", "Extra lookup path for system-wide XKB data [default=$sysconfdir/xkb]");
    const x_locale_root = b.option([]const u8, "x-locale-root", "The X locale root [default=$datadir/X11/locale]");
    const bash_completion_path = b.option([]const u8, "bash-completion-path", "Directory for bash completion scripts");
    const zsh_completion_path = b.option([]const u8, "zsh-completion-path", "Directory for zsh completion scripts");

    const default_rules = b.option([]const u8, "default-rules", "Default XKB ruleset") orelse "evdev";
    const default_model = b.option([]const u8, "default-model", "Default XKB model") orelse "pc105";
    const default_layout = b.option([]const u8, "default-layout", "Default XKB layout") orelse "us";
    const default_variant = b.option([]const u8, "default-variant", "Default XKB variant") orelse "";
    const default_options = b.option([]const u8, "default-options", "Default XKB options") orelse "";

    const enable_parser_auto_generation = b.option(bool, "enable-parser-auto-generation", "Generate parser files from `.y` grammar files (requires bison); if false, use pregenerated files shipped in the source tree") orelse true;
    const enable_tools = b.option(bool, "enable-tools", "Enable building tools") orelse true;
    const enable_x11 = b.option(bool, "enable-x11", "Enable building the xkbcommon-x11 library") orelse false; // true;
    const enable_docs = b.option(bool, "enable-docs", "Enable building the documentation") orelse false;
    const enable_cool_uris = b.option(bool, "enable-cool-uris", "Enable creating redirections to maintain stable documentation pages") orelse false;
    const enable_wayland = b.option(bool, "enable-wayland", "Enable support for Wayland utility programs (requires enable-tools)") orelse true;
    const enable_xkbregistry = b.option(bool, "enable-xkbregistry", "Enable building libxkbregistry") orelse true;
    const enable_bash_completion = b.option(bool, "enable-bash-completion", "Enable installing bash completion scripts") orelse true;
    const enable_zsh_completion = b.option(bool, "enable-zsh-completion", "Enable installing zsh completion scripts") orelse true;

    const config_header = b.addConfigHeader(.{}, .{
        .XKB_CONFIG_ROOT = xkb_config_root,
        .XKB_CONFIG_VERSIONED_EXTENSIONS_PATH = xkb_config_versioned_extensions_path,
        .XKB_CONFIG_UNVERSIONED_EXTENSIONS_PATH = xkb_config_unversioned_extensions_path,
        .XKB_CONFIG_EXTRA_PATH = xkb_config_extra_path,
        .XLOCALE_ROOT = x_locale_root,
        .XLOCALEDIR = x_locale_root orelse "/usr/share/X11/locale",
        .BASH_COMPLETION_PATH = bash_completion_path,
        .ZSH_COMPLETION_PATH = zsh_completion_path,

        .DFLT_XKB_CONFIG_ROOT = xkb_config_root orelse "/usr/share/X11/xkb",
        .DFLT_XKB_CONFIG_EXTRA_PATH = xkb_config_extra_path orelse "/etc/xkb",
        .DFLT_XKB_LEGACY_ROOT = "/usr/share/X11/xkb",

        .DEFAULT_XKB_RULES = default_rules,
        .DEFAULT_XKB_MODEL = default_model,
        .DEFAULT_XKB_LAYOUT = default_layout,
        .DEFAULT_XKB_VARIANT = default_variant,
        .DEFAULT_XKB_OPTIONS = default_options,

        .ENABLE_PARSER_AUTO_GENERATION = enable_parser_auto_generation,
        .ENABLE_TOOLS = enable_tools,
        .ENABLE_X11 = enable_x11,
        .ENABLE_DOCS = enable_docs,
        .ENABLE_COOL_URIS = enable_cool_uris,
        .ENABLE_WAYLAND = enable_wayland,
        .ENABLE_XKBREGISTRY = enable_xkbregistry,
        .ENABLE_BASH_COMPLETION = enable_bash_completion,
        .ENABLE_ZSH_COMPLETION = enable_zsh_completion,
    });

    const lib = b.addLibrary(.{
        .name = "xkbcommon",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    lib.root_module.addConfigHeader(config_header);

    lib.root_module.addCSourceFiles(.{
        .root = libxkbcommon.path("src/"),
        .files = source_files,
    });

    if (enable_x11) lib.root_module.addCSourceFiles(.{
        .root = libxkbcommon.path("src/x11/"),
        .files = source_files_x11,
    });

    lib.root_module.addIncludePath(b.path("."));
    lib.root_module.addIncludePath(libxkbcommon.path("."));
    lib.root_module.addIncludePath(libxkbcommon.path(".."));
    lib.root_module.addIncludePath(libxkbcommon.path("src/"));
    lib.root_module.addIncludePath(libxkbcommon.path("include/"));

    lib.root_module.linkLibrary(libxml2.artifact("xml"));

    lib.installHeadersDirectory(libxkbcommon.path("include/xkbcommon"), "xkbcommon", .{});

    for ([_][]const u8{
        "HAVE_MAX_ALIGN_T",
        "HAVE_STRNDUP",
        "HAVE_MMAP",
    }) |define| {
        lib.root_module.addCMacro(define, "1");
    }

    b.installArtifact(lib);

    const translate_c = b.dependency("translate_c", .{});

    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.addWriteFiles().add("c.h",
            \\#include <xkbcommon/xkbcommon.h>
        ),
        .target = target,
        .optimize = optimize,
    });
    translator.addConfigHeader(config_header);

    translator.addIncludePath(libxkbcommon.path("include/"));

    const mod = b.addModule("xkbcommon", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = translator.mod },
        },
    });

    mod.linkLibrary(lib);
}

pub const source_files: []const []const u8 = &.{
    "keymap-compare.c",
    "compose/dump.c",
    "compose/parser.c",
    "compose/state.c",
    "compose/table.c",
    "compose/paths.c",
    "registry.c",
    "keysym.c",
    "keymap-formats.c",
    "context.c",
    "keysym-case-mappings.c",
    "features.c",
    "typing.c",
    "atom.c",
    "text.c",
    "utf8-decoding.c",
    "keymap-priv.c",
    "util-paths.c",
    "scanner-utils.c",
    "util-list.c",
    "abi-check.c",
    "utils.c",
    "state.c",
    "xkbcomp/symbols.c",
    "xkbcomp/action.c",
    "xkbcomp/ast-build.c",
    "xkbcomp/keycodes.c",
    "xkbcomp/include.c",
    "xkbcomp/types.c",
    "xkbcomp/parser.c",
    "xkbcomp/keywords.c",
    "xkbcomp/vmod.c",
    "xkbcomp/rules.c",
    "xkbcomp/compat.c",
    "xkbcomp/expr.c",
    "xkbcomp/xkbcomp.c",
    "xkbcomp/keymap-dump.c",
    "xkbcomp/keymap-file-iterator.c",
    "xkbcomp/scanner.c",
    "xkbcomp/keymap.c",
    "rmlvo.c",
    "utf8.c",
    "context-priv.c",
    "keymap.c",
    "keysym-utf.c",
};

pub const source_files_x11: []const []const u8 = &.{
    "state.c",
    "util.c",
    "keymap.c",
};
