import captionBoardTest from './CaptionBoard.test';
import localUnitTest from './LocalUnit.test';
import soundCatalogTest from './SoundCatalog.test';
import soundClassesTest from './SoundClasses.test';
import soundPipelineTest from './SoundPipeline.test';
import spectrumHistoryTest from './SpectrumHistory.test';

export default function testsuite() {
  localUnitTest();
  captionBoardTest();
  soundCatalogTest();
  soundClassesTest();
  soundPipelineTest();
  spectrumHistoryTest();
}
