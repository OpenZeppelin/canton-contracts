#!/usr/bin/env bash

# Intentionally duplicated at scripts/dpm-env.sh and
# repos/oz-daml-contracts/scripts/dpm-env.sh so the repo remains independently
# buildable. Keep both copies in sync until an accepted vendoring step replaces
# the duplication.

oz_setup_java_env() {
	local java_home_candidate=""

	if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
		export PATH="$JAVA_HOME/bin:$PATH"
		oz_has_java_21 && return 0
	fi

	if [ -x /usr/libexec/java_home ]; then
		if java_home_candidate="$(/usr/libexec/java_home -v 21 2>/dev/null)"; then
			if [ -x "$java_home_candidate/bin/java" ]; then
				export JAVA_HOME="$java_home_candidate"
				export PATH="$JAVA_HOME/bin:$PATH"
				oz_has_java_21 && return 0
			fi
		fi
	fi

	for java_home_candidate in \
		/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
		/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
		/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
		/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
		if [ -x "$java_home_candidate/bin/java" ]; then
			export JAVA_HOME="$java_home_candidate"
			export PATH="$JAVA_HOME/bin:$PATH"
			oz_has_java_21 && return 0
		fi
	done
}

oz_setup_dpm_env() {
	local cache_root="${1:?cache root required}"

	export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$cache_root}"
	oz_setup_java_env || true

	if command -v dpm >/dev/null 2>&1; then
		return 0
	fi

	if [ -n "${HOME:-}" ] && [ -x "$HOME/.dpm/bin/dpm" ]; then
		export PATH="$HOME/.dpm/bin:$PATH"
	fi
}

oz_has_dpm() {
	command -v dpm >/dev/null 2>&1
}

oz_has_java_21() {
	local java_version=""

	command -v java >/dev/null 2>&1 || return 1
	java_version="$(java -version 2>&1 | head -n 1)" || return 1

	case "$java_version" in
	*\"21\"* | *\"21.*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}
