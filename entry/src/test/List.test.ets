import localUnitTest from './LocalUnit.test';
import soundCatalogTest from './SoundCatalog.test';
import soundPipelineTest from './SoundPipeline.test';
import levelHistoryTest from './LevelHistory.test';

export default function testsuite() {
  localUnitTest();
  soundCatalogTest();
  soundPipelineTest();
  levelHistoryTest();
}
