#!/bin/bash
# 隔离测试 run_simulator_tests.sh 本身：用假的 xcrun 模拟 app 的 marker/ack 握手，
# 覆盖「全部截图成功」「app 报 FAIL」「app 提前退出」三种情况。
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT

mkdir -p "$workspace/bin" "$workspace/container"
export MOCK_CONTAINER="$workspace/container"

cat > "$workspace/bin/xcrun" <<'MOCK'
#!/bin/bash
cmd=$1; shift
if [ "$cmd" = "simctl" ]; then cmd=$1; shift; fi
case "$cmd" in
  get_app_container)
    echo "$MOCK_CONTAINER"; exit 0 ;;
  terminate)
    exit 0 ;;
  io)
    # simctl io <udid> screenshot <path>
    out="${@: -1}"
    mkdir -p "$(dirname "$out")"
    printf 'PNGDATA' > "$out"
    exit 0 ;;
  launch)
    # simctl launch --console <udid> <bundle> <argument>
    arg="${@: -1}"
    case "$arg" in
      -autoSmoke) mode=smoke ;;
      -autoTest) mode=autotest ;;
      *) echo "mock app: unknown argument $arg" >&2; exit 1 ;;
    esac
    dir="$MOCK_CONTAINER/tmp/$mode"
    mkdir -p "$dir"
    # 纯 bash 模拟 app 行为，避免 Windows 上 python3 只是应用商店别名
    case "$mode" in
      smoke)
        names="01-route 02-scan 03-detail-airpods 04-detail-sony 05-handbook"
        bottoms=
        for name in $names; do bottoms="$bottoms bottom-$name"; done ;;
      autotest) names=""; bottoms="" ;;
    esac
    for name in $names $bottoms; do
      : > "$dir/now-$name"
      deadline=$(( $(date +%s) + 30 ))
      while [ ! -f "$dir/ack-$name" ]; do
        if [ "$(date +%s)" -gt "$deadline" ]; then
          echo "mock app: ack timeout $name" >&2
          exit 1
        fi
        sleep 0.1
      done
    done
    if [ "${MOCK_EARLY_EXIT:-0}" = "1" ]; then
      echo "mock app: exiting early" >&2
      exit 0
    fi
    if [ "${MOCK_FAIL:-0}" = "1" ]; then
      printf 'FAIL mock —— 故意失败\nRESULT: 1 FAILURES\n' > "$dir/result.txt"
      printf 'FAIL' > "$dir/done.txt"
    else
      printf 'RESULT: ALL PASS\n' > "$dir/result.txt"
      printf 'PASS' > "$dir/done.txt"
    fi
    exit 0 ;;
  *)
    echo "mock xcrun: unsupported $cmd" >&2; exit 1 ;;
esac
MOCK
chmod +x "$workspace/bin/xcrun"

run_case() {
  local label=$1 expected=$2
  shift 2
  set +e
  ( cd "$workspace" && env PATH="$workspace/bin:$PATH" "$@" "${here}/run_simulator_tests.sh" fake-udid smoke ) > "$workspace/$label.log" 2>&1
  local code=$?
  set -e
  if [ "$code" -ne "$expected" ]; then
    echo "FAIL runner gate: $label 期望退出码 $expected，实际 $code" >&2
    cat "$workspace/$label.log" >&2
    exit 1
  fi
  echo "PASS runner gate: $label (exit $code)"
}

run_case "全部截图成功" 0 env MOCK_FAIL=0 MOCK_EARLY_EXIT=0
for name in 01-route 02-scan 03-detail-airpods 04-detail-sony 05-handbook; do
  test -s "$workspace/smoke/$name.png" || { echo "FAIL 缺截图 $name" >&2; exit 1; }
  test -s "$workspace/smoke/bottom-$name.png" || { echo "FAIL 缺底部截图 bottom-$name" >&2; exit 1; }
done
echo "PASS runner gate: 10 张截图齐全"

run_case "app 报 FAIL" 1 env MOCK_FAIL=1 MOCK_EARLY_EXIT=0
run_case "app 提前退出" 1 env MOCK_FAIL=0 MOCK_EARLY_EXIT=1
echo "RESULT: ALL PASS"
