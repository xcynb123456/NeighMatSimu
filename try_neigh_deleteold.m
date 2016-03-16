clear all;
load('test1.mat');

test_seconds = 500;
picture_seconds = 10;
poor_radis = 40;
best_radis = 10;
neigh_max = 20;
test_duration = test_seconds*100;   %this is 600s
target_addr = 65;
best_neigh_limit = 10;

fid_neigh = fopen('neigh.txt','a');
fid_best = fopen('bneigh.txt','a');

neigh_present = zeros([test_seconds/picture_seconds, neigh_max]);

neigh_count = zeros([1 100]);
for i = 1:100
    for j = 1:100
        if i ~= j
            x = pdist([coordinate_x(i),coordinate_y(i);coordinate_x(j),coordinate_y(j)]);
            if x < poor_radis
                neigh_count(i) = neigh_count(i) + 1;
            end
        end
    end
end

hb_time = round(rand([1 100])*100);

%predefine th size
neigh_table(100,neigh_max).addr = 0;
neigh_table(100,neigh_max).last_seen = 0;
neigh_table(100,neigh_max).linkq = uint16(0);

neigh_table_d(100,neigh_max).addr = 0;
neigh_table_d(100,neigh_max).linkq = uint16(0);

for i = 1:100
    for j = 1:neigh_max
        neigh_table(i,j).addr = 0;
        neigh_table(i,j).last_seen = 0;
        neigh_table(i,j).linkq = uint16(0);
    end
end

j = 0;
for i = 1:100
    radis_ideal_neigh = pdist([coordinate_x(i),coordinate_y(i);coordinate_x(target_addr),coordinate_y(target_addr)]);
    if (radis_ideal_neigh < poor_radis) && (i ~= target_addr)
        j = j + 1;
        ideal_neigh(j,1) = i;
        ideal_neigh(j,2) = radis_ideal_neigh;
    end
end
[Y, I] = sort(ideal_neigh(:,2), 'ascend');
ideal_neigh_sort = ideal_neigh(I,:);

for test_frame = 1:test_duration
    for node = 1:100
        if test_frame == hb_time(node)
            %fire a heart beat, check if neighbor heard this
            for othernode = 1:100
                if othernode ~= node
                    x = pdist([coordinate_x(othernode),coordinate_y(othernode);coordinate_x(node),coordinate_y(node)]);
                    if x < poor_radis
                        %this hb may be heart, make neigh
                        %table update
                        oldest_index = 0;
                        first_inactive = 0;
                        for neigh_index = 1:neigh_max
                            if(first_inactive == 0) && (neigh_table(othernode, neigh_index).addr ==0)
                                first_inactive = neigh_index;
                            end
                            
                            if (oldest_index == 0) || (neigh_table(othernode, neigh_index).last_seen < neigh_table(othernode, oldest_index).last_seen)
                                oldest_index = neigh_index;
                            end
                            
                            if node == neigh_table(othernode, neigh_index).addr
                                break
                            end
                        end
                        rand_num = round(rand(1)*poor_radis);
                        %if (x < best_radis) || (rand_num > (x - best_radis))
                        if rand_num > x
                            if neigh_index < neigh_max
                                neigh_table(othernode, neigh_index).linkq = neigh_table(othernode, neigh_index).linkq*2 + 1;
                                if neigh_table(othernode, neigh_index).linkq > 2^16
                                    neigh_table(othernode, neigh_index).linkq = neigh_table(othernode, neigh_index).linkq - 2^16;
                                end
                            else
                                if first_inactive == 0      %this means table is full
                                    neigh_table(othernode, oldest_index).addr = node;
                                    neigh_table(othernode, oldest_index).last_seen = test_frame;
                                    neigh_table(othernode, oldest_index).linkq = 1;
                                else
                                    neigh_table(othernode, first_inactive).addr = node;
                                    neigh_table(othernode, first_inactive).last_seen = test_frame;
                                    neigh_table(othernode, first_inactive).linkq = 1;                                    
                                end
                            end
                        else
                            if neigh_index < neigh_max
                                if(neigh_table(othernode, neigh_index).linkq >= 1)
                                    neigh_table(othernode, neigh_index).linkq = neigh_table(othernode, neigh_index).linkq*2;
                                    if neigh_table(othernode, neigh_index).linkq > 2^16
                                        neigh_table(othernode, neigh_index).linkq = neigh_table(othernode, neigh_index).linkq - 2^16;
                                    end
                                end
                            end
                        end
                    else
                        %need not to do anything, could not hear this hb
                        %no code here
                    end
                end                
            end
            hb_time(node) = hb_time(node) + 100 + round(rand(1)*10);
        end
    end
    
    if rem(test_frame, picture_seconds*100) == 0
        %predefine th size
        for i = 1:100
            for j = 1:neigh_max
                neigh_table_d(i,j).linkq = bitcount(neigh_table(i,j).linkq);
                neigh_table_d(i,j).addr = neigh_table(i,j).addr;
            end
        end

        j = 0;
        for i = 1:neigh_max
            if neigh_table_d(target_addr,i).addr > 0
                j = j + 1;
                neigh_target(j,1) = neigh_table_d(target_addr,i).addr;
                neigh_target(j,2) = neigh_table_d(target_addr,i).linkq;
            end
        end

        group = zeros([1 100]);
        [Y, I] = sort(neigh_target(:,2), 'descend');
        neigh_target_sort = neigh_target(I,:);


        %group 0 is all
        %group 1 is within range
        %group 2 is in neigh table
        %group 3 is best neigh
        %group 4 is self
        for i = 1:length(neigh_target)
            group(neigh_target(i,1)) = 2;
        end

        if length(neigh_target) > best_neigh_limit
            for i = 1:best_neigh_limit
                group(neigh_target_sort(i,1)) = 3;
            end
        end

        for i = 1:100
            if(pdist([coordinate_x(target_addr),coordinate_y(target_addr);coordinate_x(i),coordinate_y(i)]) < poor_radis)
                if group(i) == 0
                    group(i) = 1;
                end
            end
        end

        best_neigh_match_count = 0;
        for i = 1:best_neigh_limit
            for j = 1:best_neigh_limit
                if neigh_target_sort(i,1) == ideal_neigh_sort(j,1)
                    best_neigh_match_count = best_neigh_match_count + 1;
                end
            end
        end
        fprintf(fid_best, '%d\n', best_neigh_match_count);

        neigh_match_count = 0;
        if length(neigh_target_sort) == neigh_max
            for i = 1:neigh_max
                for j = 1:neigh_max
                    if neigh_target_sort(i,1) == ideal_neigh_sort(j,1)
                        neigh_match_count = neigh_match_count + 1;
                    end
                end
            end
        else
            for i = 1:length(neigh_target_sort)
                for j = 1:length(neigh_target_sort)
                    if neigh_target_sort(i,1) == ideal_neigh_sort(j,1)
                        neigh_match_count = neigh_match_count + 1;
                    end
                end
            end
        end
        fprintf(fid_neigh, '%d\n', neigh_match_count); 

        group(target_addr) = 4;
        gscatter(coordinate_x, coordinate_y, group,'kmgrb','xosdp');
        xlabel([' ' num2str(neigh_match_count) ' neigh match,  ' num2str(best_neigh_match_count) ' best match,  ' num2str(length(ideal_neigh)) ' in range']);
        title(num2str(test_frame));

        filename = sprintf(num2str(test_frame));
        filename = regexprep(filename,':','-','all');
        print('-dpng','-zbuffer','-r200',filename);
        disp(['frame ' num2str(test_frame) ' finished']);
        
        for i = 1:neigh_max
            neigh_present(uint8(test_frame/(picture_seconds*100)),i) = neigh_table_d(target_addr,i).addr;
        end

    end
end

fclose(fid_neigh);
fclose(fid_best);

for i = 1:best_neigh_limit
    neigh_present(test_seconds/picture_seconds + 1,i) = ideal_neigh_sort(i,1);
end

for i = 1:neigh_max
    neigh_present(test_seconds/picture_seconds + 2,i) = ideal_neigh_sort(i,1);
end

x = 1:test_seconds/picture_seconds + 2;
for i = 1:neigh_max
    scatter(x,neigh_present(:,i),'.','LineWidth', 1.2)
    hold on
end

print('-dpng','-zbuffer','-r200','neigh_view');
