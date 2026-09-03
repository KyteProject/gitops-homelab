set unstable := true
set quiet := true
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# https://developers.cloudflare.com/r2/examples/aws/aws-cli/
endpoint_path := 'op://homelab/cloudflare/R2_ENDPOINT_URL'
profile := 'aeon'

[private]
default:
    just --list r2

[doc('Configure the AWS CLI')]
cli-configure:
    just require aws
    aws configure --profile {{ profile }}

[doc('List the contents of a bucket')]
ls:
    just require aws op
    op user get --me >/dev/null
    aws s3 ls --profile {{ profile }} --endpoint-url "$(op read {{ endpoint_path }})"

# The Taskfile description claimed a dry run by default. It never was one:
# `aws s3 rm --recursive` deletes immediately. The description is corrected
# here rather than carried over.
[confirm('This permanently deletes every object in the bucket. Continue? [y|N]')]
[doc('Empty a bucket, deleting every object in it permanently')]
empty bucket:
    just require aws op
    op user get --me >/dev/null
    aws s3 rm s3://{{ bucket }} --profile {{ profile }} --endpoint-url "$(op read {{ endpoint_path }})" --recursive
