import { ButtonItem, Focusable, PanelSection, PanelSectionRow } from '@decky/ui';
import { FC, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { FaBan, FaEyeSlash } from 'react-icons/fa';

import { useDeckyState } from './DeckyState';
import NotificationBadge from './NotificationBadge';
import PluginCrashBoundary from './PluginCrashBoundary';
import { useQuickAccessVisible } from './QuickAccessVisibleState';
import TitleView from './TitleView';

const PluginView: FC = () => {
  const {
    plugins,
    disabledPlugins,
    hiddenPlugins,
    updates,
    activePlugin,
    pluginOrder,
    setActivePlugin,
    closeActivePlugin,
  } = useDeckyState();
  const visible = useQuickAccessVisible();
  const { t } = useTranslation();

  const pluginList = useMemo(() => {
    console.log('updating PluginView after changes');

    return [...plugins]
      .sort((a, b) => pluginOrder.indexOf(a.name) - pluginOrder.indexOf(b.name))
      .filter((p) => p.content)
      .filter(({ name }) => !hiddenPlugins.includes(name));
  }, [plugins, pluginOrder, hiddenPlugins]);

  const numberOfHidden = hiddenPlugins.filter((name) => !!plugins.find((p) => p.name === name)).length;

  if (activePlugin) {
    return (
      <Focusable onCancelButton={closeActivePlugin}>
        <TitleView />
        <div style={{ height: '100%', paddingTop: '16px' }}>
          <PluginCrashBoundary pluginName={activePlugin.name}>
            {(visible || activePlugin.alwaysRender) && activePlugin.content}
          </PluginCrashBoundary>
        </div>
      </Focusable>
    );
  }
  return (
    <>
      <TitleView />
      <div
        style={{
          paddingTop: '16px',
        }}
      >
        <PanelSection>
          {pluginList.map(({ name, icon }) => (
            <PluginCrashBoundary key={name} pluginName={name}>
              <PanelSectionRow>
                <ButtonItem layout="below" onClick={() => setActivePlugin(name)}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                    {icon}
                    <div>{name}</div>
                    <NotificationBadge show={updates?.has(name)} style={{ top: '-5px', right: '-5px' }} />
                  </div>
                </ButtonItem>
              </PanelSectionRow>
            </PluginCrashBoundary>
          ))}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              position: 'absolute',
              justifyContent: 'center',
              padding: '5px 0px',
            }}
          >
            {numberOfHidden > 0 && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '0.8rem' }}>
                <FaEyeSlash />
                <div>{t('PluginView.hidden', { count: numberOfHidden })}</div>
              </div>
            )}
            {disabledPlugins.length > 0 && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '0.8rem' }}>
                <FaBan />
                <div>{t('PluginView.disabled', { count: disabledPlugins.length })}</div>
              </div>
            )}
          </div>
        </PanelSection>
      </div>
    </>
  );
};

export default PluginView;
