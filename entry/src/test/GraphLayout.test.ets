/**
 * 本地单元测试（M11）：知识图谱纯布局层。
 * 覆盖：节点/边构建规则、推荐锚点与依据文案、布局确定性、视口适配。
 */

import { describe, it, expect } from '@ohos/hypium';
import { Heritage } from '../main/ets/model/Heritage';
import { HeritageEra, HeritageType, HeritageCity } from '../main/ets/model/Types';
import { Theme } from '../main/ets/model/Theme';
import { GraphModel, GraphNode, GraphNodeKind, GraphEdgeKind } from '../main/ets/components/graph/GraphNode';
import {
  buildGraphModel, findBestAnchor, buildRecommendReason, layoutGraph,
  computeBounds, computeFitTransform, GraphBounds, GraphTransform
} from '../main/ets/components/graph/GraphLayout';
import { makeHeritage, makeTheme } from './TestFixtures';

const THEME: Theme = makeTheme('t1', '彩陶文化', 0);
const A: Heritage = makeHeritage('a', '甲', HeritageEra.YANGSHAO,
  HeritageType.CAPITAL_SITE, HeritageCity.LUOYANG);
const B: Heritage = makeHeritage('b', '乙', HeritageEra.YANGSHAO,
  HeritageType.TOMB_GROUP, HeritageCity.LUOYANG);
const REC: Heritage = makeHeritage('c', '丙', HeritageEra.YANGSHAO,
  HeritageType.KILN_SITE, HeritageCity.KAIFENG);

function countKind(model: GraphModel, kind: GraphNodeKind): number {
  let count: number = 0;
  for (let i = 0; i < model.nodes.length; i++) {
    if (model.nodes[i].kind === kind) {
      count += 1;
    }
  }
  return count;
}

function countEdgeKind(model: GraphModel, kind: GraphEdgeKind): number {
  let count: number = 0;
  for (let i = 0; i < model.edges.length; i++) {
    if (model.edges[i].kind === kind) {
      count += 1;
    }
  }
  return count;
}

export default function graphLayoutTest() {
  describe('BuildGraphModel', () => {
    it('buildsThemeHeritageAndRecommendNodes', 0, () => {
      const model: GraphModel = buildGraphModel(THEME, [A, B], [REC], true, true);
      expect(model.nodes.length).assertEqual(4);
      expect(countKind(model, GraphNodeKind.THEME)).assertEqual(1);
      expect(countKind(model, GraphNodeKind.HERITAGE)).assertEqual(2);
      expect(countKind(model, GraphNodeKind.RECOMMEND)).assertEqual(1);
      expect(countEdgeKind(model, GraphEdgeKind.CONTAINS)).assertEqual(2);
      expect(countEdgeKind(model, GraphEdgeKind.AFFINITY)).assertEqual(1);
      expect(countEdgeKind(model, GraphEdgeKind.RECOMMEND)).assertEqual(1);
    });
    it('omitsRecommendAndAffinityWhenLayersOff', 0, () => {
      const model: GraphModel = buildGraphModel(THEME, [A, B], [REC], false, false);
      expect(countKind(model, GraphNodeKind.RECOMMEND)).assertEqual(0);
      expect(countEdgeKind(model, GraphEdgeKind.AFFINITY)).assertEqual(0);
      expect(countEdgeKind(model, GraphEdgeKind.RECOMMEND)).assertEqual(0);
    });
    it('returnsEmptyModelWithoutTheme', 0, () => {
      const model: GraphModel = buildGraphModel(null, [A], [REC], true, true);
      expect(model.nodes.length).assertEqual(0);
      expect(model.edges.length).assertEqual(0);
    });
    it('anchorsRecommendToMostSimilarHeritage', 0, () => {
      const model: GraphModel = buildGraphModel(THEME, [A, B], [REC], false, true);
      let recommendSource: string = '';
      for (let i = 0; i < model.edges.length; i++) {
        if (model.edges[i].kind === GraphEdgeKind.RECOMMEND) {
          recommendSource = model.edges[i].sourceKey;
        }
      }
      expect(recommendSource).assertEqual('h:a');
    });
  });

  describe('RecommendAnchor', () => {
    it('findBestAnchorUsesFirstOnTie', 0, () => {
      const anchor: Heritage | null = findBestAnchor(REC, [A, B]);
      expect(anchor === null).assertEqual(false);
      expect(anchor === null ? '' : anchor.id).assertEqual('a');
    });
    it('reasonIncludesSharedTraits', 0, () => {
      const reason: string = buildRecommendReason(REC, A);
      expect(reason.indexOf('同年代') >= 0).assertEqual(true);
      expect(reason.indexOf('同城市') >= 0).assertEqual(false);
      expect(reason.indexOf('同类型') >= 0).assertEqual(false);
    });
    it('returnsNullAnchorWithoutHeritage', 0, () => {
      expect(findBestAnchor(REC, []) === null).assertEqual(true);
    });
  });

  describe('LayoutAndViewport', () => {
    it('layoutIsDeterministicAndThemeStaysPinned', 0, () => {
      const modelA: GraphModel = buildGraphModel(THEME, [A, B], [REC], true, true);
      const modelB: GraphModel = buildGraphModel(THEME, [A, B], [REC], true, true);
      layoutGraph(modelA);
      layoutGraph(modelB);
      for (let i = 0; i < modelA.nodes.length; i++) {
        expect(Math.abs(modelA.nodes[i].x - modelB.nodes[i].x) < 0.000001).assertEqual(true);
        expect(Math.abs(modelA.nodes[i].y - modelB.nodes[i].y) < 0.000001).assertEqual(true);
      }
      for (let i = 0; i < modelA.nodes.length; i++) {
        const node: GraphNode = modelA.nodes[i];
        if (node.kind === GraphNodeKind.THEME) {
          expect(node.x).assertEqual(0);
          expect(node.y).assertEqual(0);
        }
        expect(Number.isFinite(node.x)).assertEqual(true);
        expect(Number.isFinite(node.y)).assertEqual(true);
      }
    });
    it('boundsAndTransformFitCanvas', 0, () => {
      const model: GraphModel = buildGraphModel(THEME, [A, B], [REC], true, true);
      layoutGraph(model);
      const bounds: GraphBounds = computeBounds(model);
      expect(bounds.maxX - bounds.minX > 0).assertEqual(true);
      expect(bounds.maxY - bounds.minY > 0).assertEqual(true);
      const transform: GraphTransform = computeFitTransform(model, 300, 400);
      expect(transform.scale >= 0.45 && transform.scale <= 1.35).assertEqual(true);
      expect(Number.isFinite(transform.offsetX)).assertEqual(true);
      expect(Number.isFinite(transform.offsetY)).assertEqual(true);
    });
    it('emptyModelFallsBackToCenter', 0, () => {
      const model: GraphModel = buildGraphModel(null, [], [], false, false);
      const transform: GraphTransform = computeFitTransform(model, 300, 400);
      expect(transform.scale).assertEqual(1);
      expect(transform.offsetX).assertEqual(150);
      expect(transform.offsetY).assertEqual(200);
    });
  });
}
