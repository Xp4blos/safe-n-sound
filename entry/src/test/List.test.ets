import localUnitTest from './LocalUnit.test';
import soundCatalogTest from './SoundCatalog.test';

export default function testsuite() {
  localUnitTest();
  soundCatalogTest();
}
