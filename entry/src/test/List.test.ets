import coreLogicTest from './CoreLogic.test';
import recommendationTest from './Recommendation.test';
import graphLayoutTest from './GraphLayout.test';

export default function testsuite() {
  coreLogicTest();
  recommendationTest();
  graphLayoutTest();
}
