# Run: bash ~/.claude/hooks/tests/test_guard_podman_prune.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/guard-podman-prune.sh"
pass=0; fail=0
run() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$SCRIPT" >/dev/null 2>&1; echo $?; }
check() { if [ "$(run "$2")" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: [$2] want rc=$3"; fi; }

# Unfiltered remove-all: blocked (rc=2).
check test_image_prune_a_f_blocked          'podman image prune -a -f'                       2
check test_image_prune_af_combined_blocked  'podman image prune -af'                         2
check test_image_prune_all_long_blocked     'podman image prune --all --force'               2
check test_system_prune_a_blocked           'podman system prune -a'                         2
check test_docker_system_prune_a_blocked    'docker system prune -a -f'                      2
check test_rmi_all_blocked                  'podman rmi -a'                                  2
check test_sudo_prefix_blocked              'sudo podman image prune -a'                     2
check test_second_segment_blocked           'podman ps; podman image prune -a -f'            2
check test_filter_in_other_segment_blocked  'podman ps --filter x; podman image prune -a'    2
check test_image_rm_all_blocked            'podman image rm --all'                          2
check test_image_rm_a_blocked              'podman image rm -a'                             2
check test_absolute_binary_blocked         '/usr/bin/podman image prune -a'                 2
check test_shell_c_wrapper_blocked         'bash -c "podman system prune -af"'              2
check test_all_equals_true_blocked         'podman image prune --all=true'                  2
check test_filter_only_in_comment_blocked  'podman image prune -a # --filter until=168h'    2
check test_after_background_amp_blocked    'echo --filter & podman image prune -a'          2
check test_rmi_substituted_id_list_blocked  'podman rmi $(podman images -q)'                 2
check test_rmi_xargs_id_list_blocked       'podman images -q | xargs podman rmi'            2
check test_rmi_force_unfiltered_list_blocked 'docker rmi -f $(docker images -q)'            2
check test_filter_in_earlier_command_blocked 'podman images -f dangling=true; podman rmi $(podman images -q)' 2
check test_filter_in_later_pipeline_stage_blocked 'docker images -q | xargs docker rmi | docker images -f dangling=true' 2

# Allowed (rc=0).
check test_rmi_filtered_substitution_allowed 'podman rmi $(podman images -q --filter dangling=true)' 0
check test_rmi_short_filter_substitution_allowed 'docker rmi $(docker images -f "dangling=true" -q)' 0
check test_rmi_xargs_filtered_listing_allowed 'docker images -f dangling=true -q | xargs docker rmi' 0
check test_image_prune_dangling_allowed     'podman image prune -f'                          0
check test_image_prune_a_filter_allowed     'podman image prune -a --filter until=168h'      0
check test_rmi_by_name_allowed              'podman rmi localhost/app-ci-matrix:abc'      0
check test_images_list_allowed              'podman images -a'                               0
check test_ps_all_allowed                   'podman ps -a'                                   0
check test_volume_rm_allowed                'podman volume rm -f appci-x'                    0
check test_unrelated_command_allowed        'git log -a'                                     0
check test_empty_command_allowed            ''                                               0

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
