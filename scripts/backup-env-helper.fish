# Helper for managing K8up backups AND Standard CronJobs Restic environment

function _backup_list
    # List all K8up Schedules and CronJobs with aligned columns
    # We fetch both resource types in one go
    set json (kubectl get schedules,cronjobs --all-namespaces -o json 2>/dev/null)

    if test $status -ne 0
        echo "❌ Failed to get resources from Kubernetes" >&2
        return 1
    end

    if test (echo $json | jq '.items | length') -eq 0
        echo "No backups found."
        return 0
    end

    # Build table rows using jq. 
    # Logic: If it's a K8up Schedule, take .spec.backup.schedule. If CronJob, take .spec.schedule
    set -l rows (echo $json | jq -r '.items[] | "\(.kind)|\(.metadata.namespace)|\(.metadata.name)|\(if .kind == "CronJob" then .spec.schedule else .spec.backup.schedule end // "-")"' | sort)

    # Print header + underline, then rows, and pipe through column -t
    begin
        echo -e "Kind|Namespace|Name|Schedule"
        echo -e "────|─────────|────|────────"
        for row in $rows
            echo -e $row
        end
    end | column -t -s '|'
end

function _resolve_secret_value
    set ns $argv[1]
    set secret_name $argv[2]
    set secret_key $argv[3]

    if test -n "$secret_name" -a -n "$secret_key"
        kubectl get secret $secret_name -n $ns -o jsonpath="{.data.$secret_key}" 2>/dev/null | base64 --decode
    end
end

function _load_k8up_schedule
    set sched $argv[1]
    set ns $argv[2]

    # --- RESTIC_REPOSITORY ---
    set endpoint (echo $sched | jq -r '.spec.backend.s3.endpoint // empty')
    set bucket (echo $sched | jq -r '.spec.backend.s3.bucket // empty')
    
    if test -n "$endpoint" -a -n "$bucket"
        set -gx RESTIC_REPOSITORY "s3:$endpoint/$bucket"
    end

    # --- RESTIC_PASSWORD ---
    set pw_secret (echo $sched | jq -r '.spec.backend.repoPasswordSecretRef.name // empty')
    set pw_key (echo $sched | jq -r '.spec.backend.repoPasswordSecretRef.key // empty')
    set -gx RESTIC_PASSWORD (_resolve_secret_value $ns $pw_secret $pw_key)

    # --- AWS_ACCESS_KEY_ID ---
    set id_secret (echo $sched | jq -r '.spec.backend.s3.accessKeyIDSecretRef.name // empty')
    set id_key (echo $sched | jq -r '.spec.backend.s3.accessKeyIDSecretRef.key // empty')
    set -gx AWS_ACCESS_KEY_ID (_resolve_secret_value $ns $id_secret $id_key)

    # --- AWS_SECRET_ACCESS_KEY ---
    set sk_secret (echo $sched | jq -r '.spec.backend.s3.secretAccessKeySecretRef.name // empty')
    set sk_key (echo $sched | jq -r '.spec.backend.s3.secretAccessKeySecretRef.key // empty')
    set -gx AWS_SECRET_ACCESS_KEY (_resolve_secret_value $ns $sk_secret $sk_key)
end

function _load_cronjob
    set job $argv[1]
    set ns $argv[2]
    
    # We assume the variables are in the first container
    set container_env (echo $job | jq '.spec.jobTemplate.spec.template.spec.containers[0].env')

    # List of variables we want to extract
    set vars RESTIC_REPOSITORY RESTIC_PASSWORD AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY

    for var in $vars
        # 1. Try direct Value
        set val (echo $container_env | jq -r --arg v "$var" '.[] | select(.name == $v) | .value // empty')
        
        # 2. If no direct value, try ValueFrom Secret
        if test -z "$val"
            set sec_name (echo $container_env | jq -r --arg v "$var" '.[] | select(.name == $v) | .valueFrom.secretKeyRef.name // empty')
            set sec_key (echo $container_env | jq -r --arg v "$var" '.[] | select(.name == $v) | .valueFrom.secretKeyRef.key // empty')
            
            if test -n "$sec_name"
                set val (_resolve_secret_value $ns $sec_name $sec_key)
            end
        end

        if test -n "$val"
            set -gx $var "$val"
        end
    end
end

function _backup_load
    set name $argv[1]

    if test -z "$name"
        echo "❌ Missing resource name."
        echo "Usage: backup-env-setup load <name>"
        return 1
    end

    # Find the resource (searching both Schedules and CronJobs)
    set resource_info (kubectl get schedules,cronjobs --all-namespaces -o json | jq -r --arg n "$name" '.items[] | select(.metadata.name == $n) | "\(.kind) \(.metadata.namespace)"' | head -n1)

    if test -z "$resource_info"
        echo "❌ Backup resource '$name' not found."
        return 1
    end

    # Split info into Kind and Namespace
    set kind (echo $resource_info | cut -d ' ' -f1)
    set ns (echo $resource_info | cut -d ' ' -f2)

    echo "🔍 Found $kind '$name' in namespace '$ns'..."

    # Fetch the full JSON object
    if test "$kind" = "Schedule"
        set json (kubectl get schedule $name -n $ns -o json)
        _load_k8up_schedule "$json" "$ns"
    else if test "$kind" = "CronJob"
        set json (kubectl get cronjob $name -n $ns -o json)
        _load_cronjob "$json" "$ns"
    else
        echo "❌ Unsupported Kind: $kind"
        return 1
    end

    echo "✅ Environment loaded for $kind '$name'"
    # Optional: Print what was loaded (masked) to confirm
    if set -q RESTIC_REPOSITORY
        echo "   -> Repo: $RESTIC_REPOSITORY"
    end
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
            echo "  list     List all K8up schedules and CronJobs"
            echo "  load     Load Restic environment variables for a resource"
            echo "  unload   Unset backup-related environment variables"
            return 1
    end
end

# --- Autocompletion setup ---
complete -c backup-env-setup -f
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "list" -d "List backups"
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "load" -d "Load Restic environment vars"
complete -c backup-env-setup -n "not __fish_seen_subcommand_from list load unload" -a "unload" -d "Unset Restic-related env vars"

# Autocomplete names for "load" (fetching both Schedules and CronJobs)
complete -c backup-env-setup -n "__fish_seen_subcommand_from load" -a "(kubectl get schedules,cronjobs --all-namespaces -o json | jq -r '.items[].metadata.name' 2>/dev/null)" -d "Available Backups"