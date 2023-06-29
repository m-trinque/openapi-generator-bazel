# Copyright 2019 OpenAPI-Generator-Bazel Contributors

load("@bazel_tools//tools/build_defs/repo:jvm.bzl", "jvm_maven_import_external")

def openapi_tools_generator_bazel_repositories(
        openapi_generator_cli_version = "6.5.0",
        sha256 = "f18d771e98f2c5bb169d1d1961de4f94866d2901abc1e16177dd7e9299834721",
        prefix = "openapi_tools_generator_bazel",
        server_urls = [
            "https://repo1.maven.org/maven2",
        ]):
    jvm_maven_import_external(
        name = "openapi_tools_generator_bazel_cli",
        artifact_sha256 = sha256,
        artifact = "org.openapitools:openapi-generator-cli:" + openapi_generator_cli_version,
        server_urls = server_urls,
    )
    native.bind(
        name = prefix + "/dependency/openapi-generator-cli",
        actual = "@" + prefix + "_cli//jar",
    )

def _create_comma_separated_pairs(pairs):
    return ",".join([
        "{}={}".format(k, v)
        for k, v in pairs.items()
    ])

def _openapi_generator_impl(ctx):
    input_files = [
        ctx.file.openapi_generator_cli,
        ctx.file.spec,
        ctx.file.config,
    ]

    output_files = [ctx.actions.declare_file(out) for out in ctx.attr.outs]
    java_path = ctx.attr._jdk[java_common.JavaRuntimeInfo].java_executable_exec_path

    command_parts = [
        java_path,
        "-jar",
        ctx.file.openapi_generator_cli.path,
        "generate",
        "-i",
        ctx.file.spec.path,
        "-g",
        ctx.attr.generator,
        "-o",
        output_files[0].dirname,
        "-p",
        _create_comma_separated_pairs(ctx.attr.system_properties),
        "--additional-properties",
        _create_comma_separated_pairs(ctx.attr.additional_properties),
        "--type-mappings",
        _create_comma_separated_pairs(ctx.attr.type_mappings),
        "--reserved-words-mappings",
        ",".join(ctx.attr.reserved_words_mappings),
        "--config",
        ctx.file.config.path,
    ]

    for attribute in ["template_dir", "api_package", "invoker_package", "model_package", "engine"]:
        value = getattr(ctx.attr, attribute)
        if value:
            command_parts.extend(["--{}".format(attribute.replace("_", "-")), value])

    command = " ".join(command_parts)

    ctx.actions.run_shell(
        inputs = input_files,
        outputs = output_files,
        command = command,
        tools = ctx.files._jdk,
    )

    return DefaultInfo(files = depset(output_files))

_openapi_generator = rule(
    attrs = {
        "deps": attr.label_list(allow_files = True),
        "spec": attr.label(allow_single_file = [".json", ".yaml", ".yml"], mandatory = True),
        "template_dir": attr.string(),
        "config": attr.label(allow_single_file = [".yaml", ".yml"], mandatory = True),
        "generator": attr.string(mandatory = True),
        "api_package": attr.string(),
        "invoker_package": attr.string(),
        "model_package": attr.string(),
        "additional_properties": attr.string_dict(),
        "system_properties": attr.string_dict(),
        "engine": attr.string(),
        "type_mappings": attr.string_dict(),
        "reserved_words_mappings": attr.string_list(),
        "outs": attr.string_list(mandatory = True),
        "_jdk": attr.label(default = Label("@bazel_tools//tools/jdk:current_java_runtime"), providers = [java_common.JavaRuntimeInfo]),
        "openapi_generator_cli": attr.label(
            cfg = "host",
            default = Label("//external:openapi_tools_generator_bazel/dependency/openapi-generator-cli"),
            allow_single_file = True,
        ),
    },
    implementation = _openapi_generator_impl,
)

def openapi_generator(name, **kwargs):
    _openapi_generator(
        name = name,
        **kwargs
    )
