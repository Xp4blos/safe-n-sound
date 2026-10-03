import localUnitTest from './LocalUnit.test';
import soundCatalogTest from './SoundCatalog.test';
import soundPipelineTest from './SoundPipeline.test';

export default function testsuite() {
  localUnitTest();
  soundCatalogTest();
  soundPipelineTest();
}
