import json, glob, os, shutil
from datetime import datetime

def main():
    scans_dir = '/data/scans'
    report = {
        'images': [],
        'last_update': datetime.utcnow().isoformat() + 'Z'
    }

    for json_file in glob.glob(os.path.join(scans_dir, '*.json')):
        try:
            with open(json_file) as f:
                data = json.load(f)

            artifact = data.get('ArtifactName', 'unknown')
            if ':' in artifact and not artifact.endswith(':'):
                name, tag = artifact.rsplit(':', 1)
            else:
                name, tag = artifact, 'latest'

            # Flatten all vulnerabilities from all result targets (OS + language pkgs)
            vulns = []
            for res in data.get('Results', []):
                for v in res.get('Vulnerabilities', []):
                    vulns.append({
                        'cve': v.get('VulnerabilityID', 'N/A'),
                        'package': v.get('PkgName', 'N/A'),
                        'installed_version': v.get('InstalledVersion', 'N/A'),
                        'fixed_version': v.get('FixedVersion', 'No fix available'),
                        'severity': v.get('Severity', 'UNKNOWN'),
                        'description': v.get('Description', 'No description available'),
                        'url': v.get('PrimaryURL', '#'),
                        'status': v.get('Status', 'open')
                    })

            counts = {'CRITICAL':0, 'HIGH':0, 'MEDIUM':0, 'LOW':0, 'UNKNOWN':0}
            for v in vulns:
                sev = v['severity']
                counts[sev if sev in counts else 'UNKNOWN'] += 1

            report['images'].append({
                'full_name': artifact,
                'name': name,
                'tag': tag,
                'total_vulns': len(vulns),
                'counts': counts,
                'vulnerabilities': vulns,
                'last_scan': datetime.utcnow().isoformat() + 'Z'
            })
        except Exception as e:
            print(f"Error processing {json_file}: {e}")

    with open('/data/report.json', 'w') as f:
        json.dump(report, f, indent=2)

    # Copy to web root (Nginx serves it)
    shutil.copy('/data/report.json', '/usr/share/nginx/html/report.json')
    print(f"Report generated with {len(report['images'])} images")

if __name__ == "__main__":
    main()