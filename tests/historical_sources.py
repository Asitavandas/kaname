"""Sources admitted by immutable dev45 operator deliveries, before CRL refresh.

Historical archive/file pins stay exact when the current product advances.
Current service source pin validation is independent of these fixtures.
"""
FROZEN = {
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
