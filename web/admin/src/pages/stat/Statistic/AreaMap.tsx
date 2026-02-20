import { TrendData } from '@/api';
import { getApiV1StatGeoCount } from '@/request/Stat';
import Nodata from '@/assets/images/nodata.png';
import Card from '@/components/Card';
import MapChart from '@/components/MapChart';
import { useAppSelector } from '@/store';
import { Box, Stack } from '@mui/material';
import { useEffect, useState } from 'react';
import { ActiveTab, TimeList } from '.';

const AreaMap = ({ tab }: { tab: ActiveTab }) => {
  const { kb_id } = useAppSelector(state => state.config);
  const [list, setList] = useState<TrendData[]>([]);

  useEffect(() => {
    if (!kb_id) return;
    getApiV1StatGeoCount({ kb_id, day: tab }).then(res => {
      const list = Object.entries(res as Record<string, number>)
        .map(([key, value]) => {
          const [country, province, city] = key.split('|');
          return {
            name: country || '未知',
            count: value,
          };
        })
        .filter(item => !!item.name);

      const countryMap = new Map();
      for (let i = 0; i < list.length; i++) {
        if (!countryMap.has(list[i].name)) {
          countryMap.set(list[i].name, list[i].count);
        } else {
          countryMap.set(
            list[i].name,
            countryMap.get(list[i].name)! + list[i].count,
          );
        }
      }
      setList(
        Array.from(countryMap, ([name, count]) => ({ name, count })).sort(
          (a, b) => b.count - a.count,
        ),
      );
    });
  }, [kb_id, tab]);

  return (
    <Card
      sx={{
        flex: 1,
        bgcolor: 'background.paper3',
        position: 'relative',
      }}
    >
      <MapChart map='world' data={list} tooltipText={'用户数量'} />
      <Box
        sx={{
          position: 'absolute',
          left: 16,
          top: 16,
          fontSize: 16,
          fontWeight: 'bold',
        }}
      >
        访问来源分布
      </Box>
      <Box
        sx={{
          position: 'absolute',
          top: 16,
          right: 232,
          fontSize: 12,
          width: 100,
          textAlign: 'right',
          color: 'text.tertiary',
        }}
      >
        {TimeList.find(item => item.value === tab)?.label || ''}
      </Box>
      <Card
        sx={{
          bgcolor: '#fff',
          p: 2,
          position: 'absolute',
          width: 200,
          height: 260,
          overflow: 'auto',
          right: 16,
          top: 16,
        }}
      >
        {list.length > 0 ? (
          <Stack gap={1.5}>
            {list.map(it => (
              <Stack
                direction='row'
                alignItems='center'
                justifyContent={'space-between'}
                gap={2}
                key={it.name}
                sx={{ fontSize: 12 }}
              >
                <Stack>{it.name}</Stack>
                <Box sx={{ fontWeight: 700 }}>{it.count}</Box>
              </Stack>
            ))}
          </Stack>
        ) : (
          <Stack
            alignItems={'center'}
            justifyContent={'center'}
            sx={{ height: '100%', fontSize: 12, color: 'text.disabled' }}
          >
            <img src={Nodata} width={100} />
            暂无数据
          </Stack>
        )}
      </Card>
    </Card>
  );
};

export default AreaMap;
