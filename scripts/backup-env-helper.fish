# ~/.config/fish/functions/backup-env-setup.fish
# Helper for managing K8up backups and Restic environment

function _json_field
    set json $argv[1]
    set field $argv[2]
    echo $json | jq -r $field
end

function _backup_list
    # List all K8up Schedule objects with aligned columns
    set json (kubectl get schedules --all-namespaces -o json 2>/dev/null)
    if test $status -ne 0
        echo "❌ Failed to get schedules from Kubernetes" >&2
        return 1
    end

    if test (echo $json | jq '.items | length') -eq 0
        echo "No K8up schedules found."
        return 0
    end

    # Build table rows — each jq result as one array element (preserves newlines)
    set -l rows (echo $json | jq -r '.items[] | "\(.metadata.namespace)|\(.metadata.name)|\(.spec.backup.schedule // "-")"' | sort)

    # Print header + underline, then rows, and pipe through column -t
    begin
        echo -e "Namespace|Name|Schedule"
        echo -e "─────────|────|────────"
        for row in $rows
            echo -e $row
        end
    end | column -t -s '|'
end

function _backup_load
    set name $argv[1]

    if test -z "$name"
        echo "❌ Missing schedule name."
        echo "Usage: backup-env-setup load <schedule-name>"
        return 1
    end

    # Find namespace of schedule
    set ns (kubectl get schedule --all-namespaces -o json | jq -r --arg n "$name" '.items[] | select(.metadata.name == $n) | .metadata.namespace')
    if test -z "$ns"
        echo "❌ Schedule '$name' not found."
        return 1
    end

    # Get schedule JSON
    set sched (kubectl get schedule $name -n $ns -o json)

    # --- RESTIC_REPOSITORY ---
    set endpoint (echo $sched | jq -r '.spec.backend.s3.endpoint // empty')
    set bucket (echo $sched | jq -r '.spec.backend.s3.bucket // empty')
    if test -z "$endpoint" -o -z "$bucket"
        echo "❌ Missing S3 endpoint or bucket info in schedule."
        return 1
    end
    set -gx RESTIC_REPOSITORY "s3:$endpoint/$bucket"

    # --- RESTIC_PASSWORD ---
    set pw_secret (echo $sched | jq -r '.spec.backend.repoPasswordSecretRef.name // empty')
    set pw_key (echo $sched | jq -r '.spec.backend.repoPasswordSecretRef.key // empty')
    if test -n "$pw_secret" -a -n "$pw_key"
        set -gx RESTIC_PASSWORD (kubectl get secret $pw_secret -n $ns -o jsonpath="{.data.$pw_key}" | base64 --decode)
    end

    # --- AWS_ACCESS_KEY_ID ---
    set id_secret (echo $sched | jq -r '.spec.backend.s3.accessKeyIDSecretRef.name // empty')
    set id_key (echo $sched | jq -r '.spec.backend.s3.accessKeyIDSecretRef.key // empty')
    if test -n "$id_secret" -a -n "$id_key"
        set -gx AWS_ACCESS_KEY_ID (kubectl get secret $id_secret -n $ns -o jsonpath="{.data.$id_key}" | base64 --decode)
    end

    # --- AWS_SECRET_ACCESS_KEY ---
    set sk_secret (echo $sched | jq -r '.spec.backend.s3.secretAccessKeySecretRef.name // empty')
    set sk_key (echo $sched | jq -r '.spec.backend.s3.secretAccessKeySecretRef.key // empty')
    if test -n "$sk_secret" -a -n "$sk_key"
        set -gx AWS_SECRET_ACCESS_KEY (kubectl get secret $sk_secret -n $ns -o jsonpath="{.data.$sk_key}" | base64 --decode)
    end

    echo "✅ Environment loaded for schedule '$name' (namespace: $ns)"
end

function _backup_unload
    # Unset environment variables
    set vars RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
    set unloaded 0
    for v in $vars
        if set -q $v
            set -e $v
            set unloaded 1
        end
    end

    if test $unloaded -eq 1
        echo "🧹 Restic environment variables cleared"
    else
        echo "ℹ️  No backup-related environment variables were set."
    end
end

function backup-env-setup
    set cmd $argv[1]

    switch $cmd
        case list
            _backup_list
        case load
            _backup_load $argv[2]
        case unload
            _backup_unload
        case '*'
            echo "Usage: backup-env-setup <command>"
            echo
            echo "Commands:"
            echo "  list     List all K8up schedules in the cluster"
            echo "  load     Load Restic environment variables for a schedule"
            echo "  unload   Unset backup-related environment variables"
            return 1
    end
end

# --- Autocompletion setup ---
complete -c backup-env-setup -f
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "list" -d "List K8up schedules"
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "load" -d "Load Restic environment vars"
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "unload" -d "Unset Restic-related env vars"

# Autocomplete schedule names for "load"
complete -c backup-env-setup -n "__fish_seen_subcommand_from load" -a "(kubectl get schedules --all-namespaces -o json | jq -r '.items[].metadata.name' 2>/dev/null)" -d "Available K8up schedules"
