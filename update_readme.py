import json
import os
import re

def update_readme():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    json_path = os.path.join(script_dir, 'budget_data.json')
    readme_path = os.path.join(script_dir, 'README.md')
    
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    years = data['years']
    components = data['components']
    
    # Generate Markdown Table
    headers = ['Cost Component'] + [f'{y} (Mean %)' for y in years]
    header_line = '| ' + ' | '.join(headers) + ' |'
    align_line = '| :--- | ' + ' | '.join([':---:'] * len(years)) + ' |'
    
    rows = []
    for comp in components:
        icon_name = f"{comp.get('icon', '')} {comp['name']}".strip()
        vals = [f"{v}%" for v in comp['values']]
        row_line = '| ' + ' | '.join([icon_name] + vals) + ' |'
        rows.append(row_line)
        
    table_md = '\n'.join([header_line, align_line] + rows)
    
    with open(readme_path, 'r', encoding='utf-8') as f:
        readme_content = f.read()
        
    # Replace existing table in README or append
    table_pattern = r'\| Cost Component \|[\s\S]*?(?=\n\n|$)'
    if re.search(table_pattern, readme_content):
        updated_readme = re.sub(table_pattern, table_md, readme_content)
    else:
        updated_readme = readme_content.rstrip() + '\n\n' + table_md + '\n'
        
    with open(readme_path, 'w', encoding='utf-8') as f:
        f.write(updated_readme)
        
    print(f"Successfully populated table in {readme_path}")

if __name__ == '__main__':
    update_readme()
