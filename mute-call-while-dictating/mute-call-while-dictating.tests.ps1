# Pester 3.x — run with: Invoke-Pester -Path .\mute-call-while-dictating.tests.ps1
. (Join-Path $PSScriptRoot 'mute-call-while-dictating.ps1')

Describe 'ConvertTo-ConsentStoreKeyName' {
    It 'remplace chaque antislash du chemin par un dièse, comme Windows le fait dans le ConsentStore' {
        ConvertTo-ConsentStoreKeyName -ExecutablePath 'C:\Users\me\.local\bin\claude.exe' |
            Should Be 'C:#Users#me#.local#bin#claude.exe'
    }
}

Describe 'Resolve-MicrophoneTransition' {
    $idle = [pscustomobject]@{ Start = 100; Stop = 200 }

    It 'détecte le démarrage d''un enregistrement quand Start change' {
        $recording = [pscustomobject]@{ Start = 300; Stop = 200 }
        Resolve-MicrophoneTransition -Previous $idle -Current $recording | Should Be 'RecordingStarted'
    }

    It 'détecte la fin d''un enregistrement quand seul Stop change' {
        $released = [pscustomobject]@{ Start = 100; Stop = 400 }
        Resolve-MicrophoneTransition -Previous $idle -Current $released | Should Be 'RecordingStopped'
    }

    It 'ne signale rien quand les deux horodatages sont inchangés' {
        $same = [pscustomobject]@{ Start = 100; Stop = 200 }
        Resolve-MicrophoneTransition -Previous $idle -Current $same | Should BeNullOrEmpty
    }

    It 'privilégie le démarrage quand Start et Stop changent dans le même intervalle de sonde' {
        $both = [pscustomobject]@{ Start = 500; Stop = 450 }
        Resolve-MicrophoneTransition -Previous $idle -Current $both | Should Be 'RecordingStarted'
    }

    It 'traite un compteur à zéro (aucun usage encore tracé) comme un état valide' {
        $never = [pscustomobject]@{ Start = 0; Stop = 0 }
        $first = [pscustomobject]@{ Start = 1; Stop = 0 }
        Resolve-MicrophoneTransition -Previous $never -Current $first | Should Be 'RecordingStarted'
    }
}

Describe 'Read-MicrophoneUsage' {
    It 'lit les deux horodatages depuis la clé de registre indiquée' {
        Mock Get-ItemProperty { [pscustomobject]@{ LastUsedTimeStart = 11; LastUsedTimeStop = 22 } }
        $usage = Read-MicrophoneUsage -RegistryKeyPath 'HKCU:\any'
        $usage.Start | Should Be 11
        $usage.Stop | Should Be 22
    }
}
