import ErrorComponent from '@/components/error';
import StoreProvider from '@/provider';
import { ThemeStoreProvider } from '@/provider/themeStore';
import { getShareV1AppWebInfo } from '@/request/ShareApp';
import { getShareProV1AuthInfo } from '@/request/pro/ShareAuth';
import Script from 'next/script';
import { Box } from '@mui/material';
import { AppRouterCacheProvider } from '@mui/material-nextjs/v16-appRouter';
import type { Metadata, Viewport } from 'next';
import localFont from 'next/font/local';
import { headers, cookies } from 'next/headers';
import { getSelectorsByUserAgent } from 'react-device-detect';
import { getBasePath, getImagePath } from '@/utils';
import { getServerHeader } from '@/utils/getServerHeader';
import './globals.css';

const gilory = localFont({
  variable: '--font-gilory',
  src: [
    {
      path: '../assets/fonts/gilroy-bold-700.otf',
      weight: '700',
    },
    {
      path: '../assets/fonts/gilroy-medium-500.otf',
      weight: '400',
    },
    {
      path: '../assets/fonts/gilroy-regular-400.otf',
      weight: '300',
    },
  ],
});

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export async function generateMetadata(): Promise<Metadata> {
  const serverHeaders = await getServerHeader();
  const kbDetail: any = await getShareV1AppWebInfo({ headers: serverHeaders });
  const basePath = getBasePath(kbDetail?.base_url || '');
  const icon = getImagePath(kbDetail?.settings?.icon || '', basePath);
  
  // 使用cryptobtc作为网站名称，添加描述性内容和服务地区信息
  const title = 'cryptobtc - 加密资产百科全书 | 仅服务中国香港和中国澳门用户';
  
  return {
    metadataBase: new URL(process.env.TARGET || ''),
    title,
    description: 'cryptobtc是专注于加密资产的百科全书，提供全面的区块链和数字货币知识，包括比特币、以太坊等加密货币的详细介绍和技术解析。仅服务中国香港和中国澳门用户。',
    keywords: 'cryptobtc,加密资产,区块链,数字货币,百科全书,wiki,crypto,bitcoin,香港,澳门',
    icons: {
      icon: icon || `${basePath}/favicon.png`,
    },
    openGraph: {
      title,
      description: 'cryptobtc是专注于加密资产的百科全书，提供全面的区块链和数字货币知识，包括比特币、以太坊等加密货币的详细介绍和技术解析。仅服务中国香港和中国澳门用户。',
      images: icon ? [icon] : [],
    },
  };
}

const Layout = async ({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) => {
  const headersList = await headers();
  const userAgent = headersList.get('user-agent');
  const cookieStore = await cookies();
  const themeMode = (cookieStore.get('theme_mode')?.value || 'light') as
    | 'light'
    | 'dark';

  let error: any = null;

  const serverHeaders = await getServerHeader();
  
  const [kbDetailResolve, authInfoResolve] = await Promise.allSettled([
    getShareV1AppWebInfo({ headers: serverHeaders }),
    getShareProV1AuthInfo({ headers: serverHeaders }),
  ]);

  const authInfo: any =
    authInfoResolve.status === 'fulfilled' ? authInfoResolve.value : undefined;
  const kbDetail: any =
    kbDetailResolve.status === 'fulfilled' ? kbDetailResolve.value : undefined;

  if (
    authInfoResolve.status === 'rejected' &&
    authInfoResolve.reason.code === 403
  ) {
    error = authInfoResolve.reason;
  }

  const { isMobile } = getSelectorsByUserAgent(userAgent || '') || {
    isMobile: false,
  };

  const basePath = getBasePath(kbDetail?.base_url || '');

  return (
    <html lang='en'>
      <Script
        id='base-path'
        dangerouslySetInnerHTML={{
          __html: `window._BASE_PATH_ = '${basePath}';`,
        }}
      />
      <body
        className={`${gilory.variable} ${themeMode === 'dark' ? 'dark' : 'light'}`}
      >
        <AppRouterCacheProvider>
          <ThemeStoreProvider themeMode={themeMode}>
            <StoreProvider
              kbDetail={kbDetail}
              themeMode={themeMode || 'light'}
              mobile={isMobile}
              authInfo={authInfo}
            >
              <Box
                sx={{
                  bgcolor: 'background.paper',
                  minHeight: error ? '100vh' : 'auto',
                }}
                id='app-theme-root'
              >
                <Box sx={{ bgcolor: '#FFF3CD', color: '#856404', py: 1, px: 3, textAlign: 'center', borderBottom: '1px solid #FFEAA7', fontSize: 14 }}>
                  本网站 仅限中国香港、中国澳门地区用户 使用，仅提供区块链及加密资产相关技术科普内容，不面向其他地区提供服务。
                </Box>
                {error ? <ErrorComponent error={error} /> : children}
                <Box sx={{ bgcolor: '#FFF3CD', color: '#856404', py: 1, px: 3, textAlign: 'center', borderTop: '1px solid #FFEAA7', fontSize: 14 }}>
                  本网站 仅限中国香港、中国澳门地区用户 使用，仅提供区块链及加密资产相关技术科普内容，不面向其他地区提供服务。
                </Box>
              </Box>
            </StoreProvider>
          </ThemeStoreProvider>
        </AppRouterCacheProvider>
      </body>
    </html>
  );
};

export default Layout;
