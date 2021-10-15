param ($REPO_DIR = $(pwd))

$REPO_DIR = Resolve-Path $REPO_DIR

clear

if (-not(Test-Path "$REPO_DIR/.git"))
{
    echo "$REPO_DIR is not a repository"
    exit
}

$REPO_TREE_ISH = 'HEAD'
if ($REPO_TREE_ISH -eq $null)
{
    echo "REPO_TREE_ISH must be defined"
    exit
}

echo "Change directory $REPO_DIR"
$RUN_SCRIPT_DIR = $(pwd)
cd $REPO_DIR

echo "Creating root archive"

$REPO_NAME = $(Split-Path $REPO_DIR -Leaf)
$REPO_HASH = $(git rev-parse --short $REPO_TREE_ISH)
$ROOT_OUT_PATH = "$REPO_DIR\$REPO_NAME.zip"

git archive --format zip --output $ROOT_OUT_PATH $REPO_TREE_ISH
Get-Job | Wait-Job

echo "Creating submodules archive"
$ARCHIVE_CMD_SUB = 'git archive --prefix $path\ --format zip --output ' + $REPO_DIR + '\$(basename $PWD)-sub-$(git rev-parse --short HEAD).zip ' +  $REPO_TREE_ISH
$ARCHIVE_CMD_SUB = $ARCHIVE_CMD_SUB -replace '\\', '/'
git submodule foreach --recursive $ARCHIVE_CMD_SUB

echo "Merging archives to one dir"
Expand-Archive -LiteralPath $ROOT_OUT_PATH -Force -DestinationPath repo
Get-ChildItem $REPO_DIR -Filter "*-sub*.zip" | Expand-Archive -DestinationPath repo -Force

$(ls *.zip) > repo/hashes.txt

echo "Compress main dir"
$OUTPUT = "$RUN_SCRIPT_DIR\$REPO_NAME-$REPO_HASH.zip"
Compress-Archive -Path repo/* -DestinationPath $OUTPUT -Force -CompressionLevel Fastest

echo "Clean files"
rm -r repo
rm $ROOT_OUT_PATH
rm "$REPO_DIR\*sub-*.zip"

echo "Change directory $RUN_SCRIPT_DIR"
cd $RUN_SCRIPT_DIR


