"""Analytic regression cases for cross-head mapping, AP and exclusion policies."""
import sys
import unittest
from unittest.mock import patch
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from experiments.damage_comparison import (common_id, common_objects, eligible,
    family, match, average_precision, evaluate, contaminated_components)


def box(cls=0, conf=None, xy=(0,0,1,1)):
    result = dict(cls=cls,box=list(xy))
    if conf is not None: result['conf']=conf
    return result


class ComparisonTests(unittest.TestCase):
    def test_ids_are_not_shared(self):
        self.assertEqual([common_id('cardd',i) for i in (0,1,2)],[0,1,2])
        self.assertEqual([common_id('roboflow',i) for i in (5,2,1)],[0,1,2])
        for source, ids in [('cardd',(3,4)),('roboflow',(0,6,8))]:
            for i in ids: self.assertIsNone(common_id(source,i))

    def test_perfect_cross_head_remapping(self):
        gt=[box(0),box(1,xy=(0,0,.3,.3)),box(2,xy=(.5,.5,1,1))]
        pred=[box(5,.9),box(2,.8,xy=(0,0,.3,.3)),box(1,.7,xy=(.5,.5,1,1))]
        result=evaluate([dict(id='a',gt=gt,pred=common_objects('roboflow',pred))])
        for c in result['per_class'].values():
            self.assertEqual(c['ap50_95'],1)
            self.assertEqual(c['f1'],1)

    def test_noncommon_damage_excludes_entire_image(self):
        self.assertFalse(eligible(dict(source='cardd',gt=[box(0),box(3)])))
        self.assertFalse(eligible(dict(source='roboflow',gt=[box(5),box(0)])))
        self.assertFalse(eligible(dict(source='cardd',gt=[box()],hidden_tire=True)))
        self.assertFalse(eligible(dict(source='cardd',gt=[])))
        self.assertTrue(eligible(dict(source='cardd',gt=[box()])))

    def test_wrong_class_is_fp_and_fn(self):
        r=evaluate([dict(id='a',gt=[box(0)],pred=[box(1,.95)])])
        self.assertEqual(r['totals'],dict(tp=0,fp=1,fn=1))
        self.assertEqual(r['confusion_matrix']['values'][1][0],1)
        self.assertEqual(len(r['high_confidence_fp']),1)
        self.assertIsNone(r['per_class']['DENT']['ap50'])
        self.assertEqual(r['per_class']['SCRATCH']['ap50'],0)

    def test_duplicate_predictions_one_gt(self):
        p=[box(0,.9),box(0,.8)]
        self.assertEqual(len(match([box()],p)),1)
        r=evaluate([dict(id='a',gt=[box()],pred=p)])
        self.assertEqual(r['totals'],dict(tp=1,fp=1,fn=0))
        self.assertEqual(r['per_class']['SCRATCH']['precision'],.5)

    def test_operating_threshold_does_not_change_ap(self):
        items=[dict(id='a',gt=[box()],pred=[box(0,.2)])]
        lo,hi=evaluate(items,operating=.001),evaluate(items)
        self.assertEqual(lo['per_class']['SCRATCH']['ap50_95'],hi['per_class']['SCRATCH']['ap50_95'])
        self.assertEqual(hi['totals']['fn'],1)
        self.assertEqual(lo['totals']['tp'],1)

    def test_ap_known_ranked_false_positive(self):
        self.assertEqual(average_precision([False,True],[.9,.8],1),.5)
        self.assertEqual(average_precision([],[],1),0)
        self.assertIsNone(average_precision([],[],0))

    def test_iou_thresholds_and_boundary(self):
        g=[box()]
        p=[box(0,.9,xy=(0,0,.5,1))]
        self.assertEqual(len(match(g,p,.5)),1)
        self.assertEqual(len(match(g,p,.55)),0)
        r=evaluate([dict(id='a',gt=g,pred=p)])['per_class']['SCRATCH']
        self.assertEqual(r['ap50'],1)
        self.assertAlmostEqual(r['ap50_95'],.1)

    def test_confidence_rank_and_second_best_unused_gt(self):
        gt=[box(),box(xy=(.1,0,1,1))]
        pairs=match(gt,[box(0,.1),box(0,.9)])
        self.assertEqual(pairs[0][0],1)
        self.assertEqual(len(pairs),2)

    def test_transitive_leakage_from_either_training_source(self):
        records=[dict(split='test'),dict(split='test'),dict(split='val'),dict(split='test')]
        _,bad=contaminated_components(records,[dict(left=0,right=1),dict(left=1,right=2)])
        self.assertEqual(bad,{0,1})

    def test_filename_family(self):
        self.assertEqual(family('000012_jpg.rf.aabbccee'),'000012')
        self.assertEqual(family('000012'),'000012')

    def test_visual_review_rejects_stale_audit(self):
        from scripts import compare_cardd_roboflow_nano as runner
        with patch.object(runner,'read',side_effect=[{},dict(audit_sha256='old')]), \
             patch.object(runner,'sha256',return_value='new'):
            with self.assertRaisesRegex(ValueError,'Stale'):
                runner.reviewed_cohort(Path('unused'))

    def test_visual_review_requires_matching_image_identity(self):
        from scripts import compare_cardd_roboflow_nano as runner
        audit=dict(common_indices=[0],records=[dict(id='actual')])
        review=dict(audit_sha256='same',decisions={'0':dict(image='wrong',decision='retain_exploratory',reason='checked')})
        with patch.object(runner,'read',side_effect=[audit,review]),patch.object(runner,'sha256',return_value='same'):
            with self.assertRaisesRegex(ValueError,'Missing explicit review'):
                runner.reviewed_cohort(Path('unused'))

    def test_visual_exclusion_applies_to_whole_image_and_native_cohort(self):
        from scripts import compare_cardd_roboflow_nano as runner
        audit=dict(common_indices=[0,1],summary=dict(common_test_images=2),records=[
            dict(id='a',source='cardd',gt=[box()],deduplicated_test=True,exclusion_reasons=[]),
            dict(id='b',source='roboflow',gt=[box(5)],deduplicated_test=True,exclusion_reasons=[])])
        review=dict(audit_sha256='same',decisions={
            '0':dict(image='a',decision='exclude',reason='missing lamp'),
            '1':dict(image='b',decision='retain_exploratory',reason='checked')})
        with patch.object(runner,'read',side_effect=[audit,review]),patch.object(runner,'sha256',return_value='same'), \
             patch.object(runner,'write'):
            result=runner.reviewed_cohort(Path('unused'))
        self.assertEqual(result['common_indices'],[1])
        self.assertFalse(result['records'][0]['deduplicated_test'])
        self.assertEqual(result['summary']['common_instances'],{'SCRATCH':1})


if __name__=='__main__': unittest.main()
