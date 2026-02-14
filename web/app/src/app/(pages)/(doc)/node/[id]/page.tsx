import { getShareV1NodeDetail } from '@/request/ShareNode';
import { formatMeta } from '@/utils';
import Doc from '@/views/node';
import { ResolvingMetadata } from 'next';
import { Box, Stack } from '@mui/material';
import { IconWenjian, IconWenjianjia } from '@panda-wiki/icons';

export interface PageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata(
  { params }: PageProps,
  parent: ResolvingMetadata,
) {
  const { id } = await params;
  let node = {
    name: '无权访问',
    meta: {
      summary: '无权访问',
    },
  };
  try {
    // @ts-ignore
    node = (await getShareV1NodeDetail({ id })) as any;
  } catch (error) {
    console.log(error);
  }

  return await formatMeta(
    { title: node?.name, description: node?.meta?.summary },
    parent,
  );
}

const DocPage = async ({ params }: PageProps) => {
  const { id = '' } = await params;
  let error: any = null;
  let node: any = null;
  try {
    // @ts-ignore
    node = await getShareV1NodeDetail({ id });
  } catch (err) {
    error = err;
  }
  return (
    <Box>
      {node && (
        <h1
          style={{
            margin: 0,
            padding: 0,
            fontSize: '30px',
            lineHeight: '36px',
            fontWeight: 'bold',
            color: 'inherit',
            marginBottom: '10px',
            display: 'flex',
            alignItems: 'flex-start',
            gap: '8px',
          }}
        >
          {node?.meta?.emoji ? (
            <Box style={{ flexShrink: 0 }}>{node?.meta?.emoji}</Box>
          ) : node?.type === 1 ? (
            <IconWenjianjia style={{ flexShrink: 0, marginTop: '2px' }} />
          ) : (
            <IconWenjian style={{ flexShrink: 0, marginTop: '2px' }} />
          )}
          {node?.name}
        </h1>
      )}
      <Doc node={node} error={error} />
    </Box>
  );
};

export default DocPage;
