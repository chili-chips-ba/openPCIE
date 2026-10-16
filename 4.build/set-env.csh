#!/bin/csh
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# tcsh / csh front end of set-env.sh, which does the work. Source it from
# 4.build/, from one of its sub-folders, from 5.sim/ or from the repo root:
#   source set-env.csh            (in 4.build/)
#   source ../set-env.csh         (in 4.build/hw_build.openXC7/ or sw_build/)
#   source ../4.build/set-env.csh (in 5.sim/)

set _se_sh = ""
foreach _se_d (. .. 4.build ../4.build)
    if ( "$_se_sh" == "" && -f $_se_d/set-env.sh ) set _se_sh = $_se_d/set-env.sh
end
if ( "$_se_sh" == "" ) then
    echo "set-env.csh: source it from 4.build/, a sub-folder of it, 5.sim/ or the repo root"
else
    eval "`bash $_se_sh --csh`"
endif
unset _se_sh _se_d
