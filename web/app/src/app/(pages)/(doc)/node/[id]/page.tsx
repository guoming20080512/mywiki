import { getShareV1NodeDetail } from '@/request/ShareNode';
import { formatMeta } from '@/utils';
import Doc from '@/views/node';
import { ResolvingMetadata } from 'next';

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

  // 使用节点名称作为关键词基础
  const keywords = [
    'cryptobtc',
    '加密资产',
    '区块链',
    '数字货币',
    '币安',
    '欧易',
    node?.name,
  ].filter(Boolean);

  // 优先使用节点摘要
  const description = node?.meta?.summary;
  console.log('Node meta:', node?.meta);
  console.log('Using description:', description);

  return await formatMeta(
    {
      title: node?.name,
      description: description,
      keywords,
    },
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
    <>
      {node && (
        <>
          <h1
            style={{
              position: 'absolute',
              top: '-9999px',
              left: '-9999px',
              width: '1px',
              height: '1px',
              overflow: 'hidden',
              clip: 'rect(0, 0, 0, 0)',
            }}
          >
            {node?.name}
          </h1>
          {node.type === 2 && node.content && (
            <div
              style={{
                position: 'absolute',
                top: '-9999px',
                left: '-9999px',
                width: '1px',
                height: '1px',
                overflow: 'hidden',
                clip: 'rect(0, 0, 0, 0)',
              }}
              dangerouslySetInnerHTML={{ __html: node.content }}
            />
          )}
        </>
      )}
      <Doc node={node} error={error} />
    </>
  );
};

export default DocPage;
