def main(ctx):

    config = {
        "repo": ctx.repo.name,
        "description": "gettext extractor for go",
    }

    stages = []

    testPipelines = test(ctx)

    releasePipelines = binaryReleases(ctx)
    releasePipelines["depends_on"] = [testPipelines["name"]]

    stages = [testPipelines] + [releasePipelines]

    after = [
        notification(config),
    ]

    for s in stages:
        for a in after:
            a["depends_on"].append(s["name"])

    return stages + after

def notification(config):
    steps = [{
        "name": "notify",
        "image": "plugins/slack",
        "settings": {
            "webhook": {
                "from_secret": "private_rocketchat",
            },
            "channel": "builds",
        },
        "when": {
            "status": [
                "failure",
            ],
        },
    }]

    return {
        "kind": "pipeline",
        "type": "docker",
        "name": "notification",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "clone": {
            "disable": True,
        },
        "steps": steps,
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/heads/release",
                "refs/tags/**",
            ],
            "status": [
                "success",
                "failure",
            ],
        },
    }

def test(ctx):
    pipeline = {
        "kind": "pipeline",
        "type": "docker",
        "name": "testing",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "build",
                "image": "owncloudci/golang:1.19",
                "pull": "always",
                "commands": [
                    "make generate build",
                ],
            },
            {
                "name": "test",
                "image": "owncloudci/golang:1.19",
                "pull": "always",
                "commands": [
                    "make test",
                ],
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/heads/release",
                "refs/tags/v*",
                "refs/pull/**",
            ],
        },
    }
    return pipeline

def binaryReleases(ctx):
    pipeline = {
        "kind": "pipeline",
        "type": "docker",
        "name": "binaries-release",
        "platform": {
            "os": "linux",
            "arch": "amd64",
        },
        "steps": [
            {
                "name": "binaries",
                "image": "owncloudci/golang:1.19",
                "pull": "always",
                "commands": [
                    "make release",
                ],
                "when": {
                    "ref": [
                        "refs/heads/master",
                        "refs/heads/release",
                        "refs/tags/v*",
                        "refs/pull/**",
                    ],
                },
            },
            {
                "name": "publish",
                "image": "plugins/github-release:1",
                "pull": "always",
                "settings": {
                    "api_key": {
                        "from_secret": "github_token",
                    },
                    "files": [
                        "dist/release/*",
                    ],
                    "title": ctx.build.ref.replace("refs/tags/v", ""),
                    "overwrite": True,
                    "prerelease": len(ctx.build.ref.split("-")) > 1,
                },
                "when": {
                    "ref": [
                        "refs/tags/v*",
                    ],
                },
            },
        ],
        "depends_on": [],
        "trigger": {
            "ref": [
                "refs/heads/master",
                "refs/heads/release",
                "refs/tags/v*",
                "refs/pull/**",
            ],
        },
    }
    return pipeline
