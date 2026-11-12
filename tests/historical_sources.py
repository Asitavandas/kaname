"""Source references for immutable operator delivery tests.

Historical archive/file pins stay exact when the current product advances.
Current service source pin validation is independent of these fixtures.
"""
# Current reviewed initializer for tests which compare against historical guards.
SERVER_INIT_AST_SHA256 = '8298adcc18bd0358c8412111376d52f57a722a9a394a4d63440e9219ece5767f'

FROZEN = {
    'ConnectorServiceHost.cs': 'connector-host-dev45.cs',
    'Install-AuthWireConnectorService.ps1': 'connector-installer-dev45.ps1',
    'CombinedCandidateContent.ps1': 'combined-public-content-dev45.ps1',
    'Invoke-AuthWireCombinedJob.ps1': 'combined-job-dev45.ps1',
    'ConnectorServicePackage.ps1': 'connector-package-dev45.ps1',
    'New-AuthWireConnectorServicePackage.ps1': 'connector-builder-dev45.ps1',
    'Update-AuthWireConnectorService.ps1': 'connector-updater-dev45.ps1',
}


def connector_source(root, name):
    if name in FROZEN:
        return root/'tests/fixtures'/FROZEN[name]
    return root/'windows/connector'/name
