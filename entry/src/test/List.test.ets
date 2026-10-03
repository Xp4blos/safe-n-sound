import localUnitTest from './LocalUnit.test';
import soundCatalogTest from './SoundCatalog.test';
import soundPipelineTest from './SoundPipeline.test';
import spectrumHistoryTest from './SpectrumHistory.test';

export default function testsuite() {
  localUnitTest();
  soundCatalogTest();
  soundPipelineTest();
  spectrumHistoryTest();
}
