"""Generate catalog consumers from the audited HITL COCO catalog (no raw writes)."""
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]


def write(path,text):
    path=ROOT/path
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(text,encoding='utf-8',newline='\n')


def main():
    catalog=json.loads((ROOT/'ai-service/datasets/hitl-coco/classes.json').read_text(encoding='utf-8'))
    categories=catalog['categories']
    write('ai-service/app/vision/classes.json',json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    values={}
    for name,task in [('DamageType','damage'),('VehiclePart','part')]:
        path=Path(f'src/main/java/com/gorkem/vehicle_inspector/entity/{name}.java')
        text=(ROOT/path).read_text(encoding='utf-8')
        body=text[text.index('{')+1:text.index('}')]
        existing=re.findall(r'\b[A-Z][A-Z_]+\b',body)
        combined=list(dict.fromkeys(existing+[c['code'] for c in categories if c['task']==task]))
        values[name]=combined
        write(path,'package com.gorkem.vehicle_inspector.entity;\n\n'
            '// Legacy values are retained for historical records; HITL values preserve source semantics.\n'
            f'public enum {name} {{\n    '+',\n    '.join(combined)+'\n}\n')
    repair=Path('src/main/java/com/gorkem/vehicle_inspector/entity/RepairAction.java')
    text=(ROOT/repair).read_text(encoding='utf-8')
    existing=re.findall(r'\b[A-Z][A-Z_]+\b',text[text.index('{')+1:text.index('}')])
    values['RepairAction']=list(dict.fromkeys(existing+['PROFESSIONAL_INSPECTION']))
    write(repair,'package com.gorkem.vehicle_inspector.entity;\n\npublic enum RepairAction {\n    '+',\n    '.join(values['RepairAction'])+'\n}\n')
    entries=',\n'.join(f'            new Entry({c["id"]}, "{c["task"]}", "{c["code"]}", "{c["name"]}", "{c["display_tr"]}")' for c in categories)
    write('src/main/java/com/gorkem/vehicle_inspector/service/VisionClassCatalog.java','''package com.gorkem.vehicle_inspector.service;

import java.util.List;

/** Generated from the audited HITL catalog; preserves original names and IDs. */
public final class VisionClassCatalog {
    public record Entry(int id, String task, String code, String originalName, String turkishName) {}
    public static final List<Entry> CLASSES = List.of(
'''+entries+''');
    private VisionClassCatalog() {}
    public static Entry byName(String name) {
        return CLASSES.stream().filter(c -> c.originalName().equals(name)).findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown HITL class: " + name));
    }
    public static Entry byCode(String code) {
        return CLASSES.stream().filter(c -> c.code().equals(code)).findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown HITL code: " + code));
    }
}
''')
    sql='-- Additive HITL contract: preserve every historical enum value and row.\n'
    for table,column,kind in [('damage_detections','affected_part','VehiclePart'),
        ('damage_recommendation_parts','vehicle_part','VehiclePart'),
        ('damage_repair_recommendations','damage_type','DamageType'),
        ('damage_repair_recommendations','recommended_action','RepairAction')]:
        constraint=f'{table}_{column}_check'
        array=', '.join("'"+v+"'" for v in values[kind])
        sql+=f'ALTER TABLE {table} DROP CONSTRAINT IF EXISTS {constraint};\n'
        sql+=f'ALTER TABLE {table} ADD CONSTRAINT {constraint} CHECK ({column} IN ({array}));\n'
    sql+='''ALTER TABLE damage_inspections ADD COLUMN analysis_schema_version VARCHAR(40);
ALTER TABLE damage_inspections ADD COLUMN analysis_model_version VARCHAR(160);
ALTER TABLE damage_inspections ADD COLUMN analysis_payload TEXT;
ALTER TABLE damage_repair_recommendations ALTER COLUMN part_replacement_required DROP NOT NULL;
'''
    migration=Path('src/main/resources/db/migration/V17__unified_hitl_analysis.sql')
    if (ROOT/migration).exists() and (ROOT/migration).read_text(encoding='utf-8') != sql:
        raise ValueError('Existing V17 differs: migrations are immutable; create a new migration instead')
    write(migration,sql)
    labels=[]
    for c in categories:
        labels.append(f"    '{c['code']}': '{c['display_tr']}',")
        labels.append(f"    '{c['name']}': '{c['display_tr']}',")
    write('mobile/lib/features/inspection/models/vision_class_catalog.dart','''// Generated from the audited HITL catalog. Original IDs/names remain in API data.
class VisionClassCatalog {
  static const labels = <String, String>{
'''+ '\n'.join(labels)+'''
    'PROFESSIONAL_INSPECTION': 'Fiziksel inceleme gerekli',
  };

  static String? label(String? value) => labels[value];
}
''')
    print('Generated Python, Java, Flutter and additive V17 contracts for',len(categories),'classes')


if __name__=='__main__':
    main()
