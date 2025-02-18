param ($REPO_DIR = $(pwd))

$REPO_DIR = Resolve-Path $REPO_DIR

clear

if (-not(Test-Path "$REPO_DIR/.git"))
{
    echo "$REPO_DIR is not a repository"
    exit
}

$status = git status --untracked-files=no --porcelain

if ([string]::IsNullOrEmpty($status)) {
    # Рабочая директория чиста, за исключением неотслеживаемых файлов
    Write-Host "OK! Working directory clean excluding untracked files"
} else {
    # Есть незакоммиченные изменения в отслеживаемых файлах
    Write-Host "ERROR! Uncommitted changes in tracked files"
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

echo "Creating temporary directory"
$TMP_PATH = "$REPO_DIR/.~tmp_git_archive_all"
if (Test-Path $TMP_PATH)
{
    rmdir $TMP_PATH -r -fo
}
mkdir $TMP_PATH -Force > $null
Set-ItemProperty -LiteralPath $TMP_PATH -Name Attributes -Value Hidden

$REPO_NAME = $(Split-Path $REPO_DIR -Leaf)
$REPO_HASH = $(git rev-parse --short $REPO_TREE_ISH)
$ROOT_OUT_PATH = "$TMP_PATH\$REPO_NAME.zip"

echo "Creating superproject archive"
git archive --format zip --output $ROOT_OUT_PATH $REPO_TREE_ISH
Get-Job | Wait-Job

echo "Creating submodules archives"
$ARCHIVE_CMD_SUB = 'git archive --prefix $displaypath\ --format zip --output ' + $TMP_PATH + '\$(basename $PWD)-$(basename $(dirname "$PWD"))-sub-$(git rev-parse --short HEAD).zip ' +  $REPO_TREE_ISH
$ARCHIVE_CMD_SUB = $ARCHIVE_CMD_SUB -replace '\\', '/'
echo $ARCHIVE_CMD_SUB
git submodule foreach --recursive $ARCHIVE_CMD_SUB

echo "Merging archives to one directory"
Expand-Archive -LiteralPath $ROOT_OUT_PATH -Force -DestinationPath $TMP_PATH/repo
Get-ChildItem $TMP_PATH -Filter "*-sub*.zip" | Expand-Archive -DestinationPath $TMP_PATH/repo -Force

$(ls $TMP_PATH/*.zip) > $TMP_PATH/repo/hashes.txt

echo "Compress result directory"
$OUTPUT = "$RUN_SCRIPT_DIR\$REPO_NAME-$REPO_HASH.zip"
Compress-Archive -Path $TMP_PATH/repo/* -DestinationPath $OUTPUT -Force -CompressionLevel Fastest

echo "Clean temp"
rmdir $TMP_PATH -r -fo

echo "Change directory $RUN_SCRIPT_DIR"
cd $RUN_SCRIPT_DIR