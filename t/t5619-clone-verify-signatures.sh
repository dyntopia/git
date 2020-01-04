#!/bin/sh

test_description='Test cloning repos with signature verification'

. ./test-lib.sh
. "$TEST_DIRECTORY/lib-gpg.sh"

test_expect_success GPG 'create repositories with signed commits and tags' '
	echo 0 >a && git add a &&
	test_tick && git commit -m "initial-unsigned" &&
	git tag -a -m "unsigned v0" v0-unsigned &&

	git clone . signed &&
	(
		cd signed &&
		echo 1 >b && git add b &&
		test_tick && git commit -S -m "signed" &&
		git branch signed-branch &&
		git tag -s -m "signed v1" v1-signed
	) &&

	git clone . unsigned &&
	(
		cd unsigned &&
		echo 2 >c && git add c &&
		test_tick && git commit -m "unsigned" &&
		git tag v2-unsigned-shallow &&
		git tag -a -m "unsigned and annotated" v2-unsigned-annotated
	) &&

	git clone signed unsigned-tip &&
	(
		cd unsigned-tip &&
		echo 3 >d && git add d &&
		test_tick && git commit -m "unsigned tip" &&
		git tag -a -m "unsigned v3 tip" v3-unsigned-tip &&
		git branch signed-branch origin/signed-branch
	) &&

	git clone signed unsigned-branch &&
	(
		cd unsigned-branch &&
		git checkout -b unsigned-branch &&
		git commit --amend --no-edit &&
		git checkout master
	) &&

	git clone . signed-tag-unsigned-commit &&
	(
		cd signed-tag-unsigned-commit &&
		git tag -s -m "signed/unsigned v4" v4-signed-tag-unsigned-commit
	) &&

	git clone . bad &&
	(
		cd bad &&
		echo 4 >d && git add d &&
		test_tick && git commit -S -m "bad" &&
		git cat-file commit HEAD >raw &&
		sed -e "s/^bad/forged bad/" raw >forged &&
		git hash-object -w -t commit forged >forged.commit &&
		git checkout $(cat forged.commit)
	) &&

	git clone . untrusted &&
	(
		cd untrusted &&
		echo 5 >e && git add e &&
		test_tick && git commit -SB7227189 -m "untrusted"
	) &&

	git clone unsigned unsigned-detached &&
	(
		cd unsigned-detached &&
		echo 6 >f && git add f &&
		test_tick && git commit -S -m "signed" &&
		git checkout HEAD^
	) &&

	git clone signed signed-detached &&
	(
		cd signed-detached &&
		echo 7 >g && git add g &&
		test_tick && git commit -S -m "signed" &&
		git checkout HEAD^
	) &&

	git clone signed signed-with-unsigned-submodule &&
	(
		cd signed-with-unsigned-submodule &&
		git submodule add "file://$PWD/../unsigned" &&
		git commit -S -m "add submodule"
	) &&

	git clone signed signed-with-signed-submodule &&
	(
		cd signed-with-signed-submodule &&
		git submodule add "file://$PWD/../signed" &&
		git commit -S -m "add submodule"
	) &&

	git clone unsigned unsigned-with-unsigned-submodule &&
	(
		cd unsigned-with-unsigned-submodule &&
		git submodule add "file://$PWD/../unsigned" &&
		git commit -m "add submodule"
	) &&

	git clone unsigned unsigned-with-signed-submodule &&
	(
		cd unsigned-with-signed-submodule &&
		git submodule add "file://$PWD/../signed" &&
		git commit -m "add submodule"
	)
'

test_expect_success GPG 'clone signed with --verify-signatures' '
	test_when_finished "rm -rf dst" &&
	git clone --verify-signatures signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed tag with --verify-signatures' '
	test_when_finished "rm -rf dst" &&
	git clone -b v1-signed --verify-signatures signed dst >out &&
	test_i18ngrep "Tag [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with --depth=1 and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --depth=1 signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with --no-checkout and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --no-checkout signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with --mirror and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --mirror signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed without blobs and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --filter=blob:none signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed bare with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --bare signed dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed tag with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone -b v1-signed signed dst >out &&
	test_i18ngrep "Tag [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone unsigned with defaults' '
	test_when_finished "rm -rf dst" &&
	git clone unsigned dst >out 2>&1 &&
	! test_i18ngrep "GPG signature" out
'

test_expect_success GPG 'clone unsigned with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with --depth=1 and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --depth=1 unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with --no-checkout and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --no-checkout unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with --mirror and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --no-checkout unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned without blobs and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --filter=blob:none unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned bare with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --bare unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with --verify-signatures and clone.verifySignatures=false' '
	test_config_global clone.verifySignatures false &&
	test_must_fail git clone --verify-signatures unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with --no-verify-signatures and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --no-verify-signatures unsigned dst >out &&
	! test_i18ngrep "GPG signature" out
'

test_expect_success GPG 'clone unsigned with --no-verify-signatures and gpg.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global gpg.verifySignatures true &&
	git clone --no-verify-signatures unsigned dst >out &&
	! test_i18ngrep "GPG signature" out
'

test_expect_success GPG 'clone unsigned with clone.verifySignatures=false and gpg.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures false &&
	test_config_global gpg.verifySignatures true &&
	git clone unsigned dst >out &&
	! test_i18ngrep "GPG signature" out
'

test_expect_success GPG 'clone unsigned with gpg.verifySignatures=true and clone.verifySignatures=false' '
	test_when_finished "rm -rf dst" &&
	test_config_global gpg.verifySignatures true &&
	test_config_global clone.verifySignatures false &&
	git clone unsigned dst >out &&
	! test_i18ngrep "GPG signature" out
'

test_expect_success GPG 'clone unsigned with gpg.verifySignatures=true' '
	test_config_global gpg.verifySignatures true &&
	test_must_fail git clone unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone bad signature with --verbose and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --verbose bad dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "gpg: BAD signature from " out
'

test_expect_success GPG 'clone bad signature with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone bad dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ has a bad GPG signature " out
'

test_expect_success GPG 'clone untrusted with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone untrusted dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone untrusted with clone.verifySignatures=true and gpg.minTrustLevel=fully' '
	test_config_global clone.verifySignatures true &&
	test_config_global gpg.minTrustLevel fully &&
	test_must_fail git clone untrusted dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ has an untrusted GPG signature" out
'

test_expect_success GPG 'clone unsigned tip with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone unsigned-tip dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned tip tag with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone -b v3-unsigned-tip unsigned-tip dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Tag [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone signed tag from unsigned tip tag with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone -b v1-signed unsigned-tip dst >out &&
	test_i18ngrep "Tag [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed branch from unsigned tip tag with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone -b signed-branch unsigned-tip dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone unsigned branch with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone -b unsigned-branch unsigned-branch dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned shallow tag with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone -b v2-unsigned-shallow unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned annotated tag with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone -b v2-unsigned-annotated unsigned dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Tag [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone signed tag for unsigned commit with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone -b v4-signed-tag-unsigned-commit signed-tag-unsigned-commit dst >out &&
	test_i18ngrep "Tag [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone unsigned detached HEAD with clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone unsigned-detached dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone signed detached HEAD with clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone signed-detached dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with unsigned submodules and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --recurse-submodules signed-with-unsigned-submodule dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with unsigned submodules and --verify-signatures' '
	test_when_finished "rm -rf dst" &&
	git clone --recurse-submodules --verify-signatures \
		signed-with-unsigned-submodule dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone signed with signed submodules and clone.verifySignatures=true' '
	test_when_finished "rm -rf dst" &&
	test_config_global clone.verifySignatures true &&
	git clone --recurse-submodules signed-with-signed-submodule dst >out &&
	test_i18ngrep "Commit [0-9a-f]\+ has a good GPG signature by " out
'

test_expect_success GPG 'clone unsigned with signed submodules and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --recurse-submodules unsigned-with-signed-submodule dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with signed submodules and --verify-signatures' '
	test_must_fail git clone --recurse-submodules --verify-signatures \
		unsigned-with-signed-submodule dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_expect_success GPG 'clone unsigned with unsigned submodules and clone.verifySignatures=true' '
	test_config_global clone.verifySignatures true &&
	test_must_fail git clone --recurse-submodules unsigned-with-unsigned-submodule dst 2>out &&
	test_path_is_missing dst &&
	test_i18ngrep "Commit [0-9a-f]\+ does not have a GPG signature." out
'

test_done
